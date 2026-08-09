<?php

namespace api\modules\notify\services;

use common\models\Client;
use common\models\Notification;
use common\models\TelegramLink;
use Yii;

/**
 * Application service that queues and dispatches outbound notifications
 * (reminders, confirmations) over Telegram or SMS.
 *
 * Queuing and dispatch are split so the write path (creating a booking, cron
 * scanning upcoming appointments) can enqueue cheaply, while an async worker or
 * the same request can flush the queue via {@see dispatch()}.
 */
class NotificationService
{
    /**
     * Create a queued notification row. `businessId` is always set explicitly so
     * this works from console (no tenant context) and keeps tenant isolation
     * correct. Returns the saved model, or the unsaved model on validation error.
     */
    public static function queue(int $businessId, ?int $clientId, string $channel, string $template, array $payload = []): Notification
    {
        $n = new Notification();
        $n->business_id = $businessId;
        $n->client_id = $clientId;
        $n->channel = $channel;
        $n->template = $template;
        $n->payload = $payload ?: null;
        $n->status = Notification::STATUS_QUEUED;

        if (!$n->save()) {
            Yii::warning('Failed to queue notification: ' . json_encode($n->getErrors()), 'notify');
        }
        return $n;
    }

    /**
     * Resolve the recipient, render the message and send it via the right
     * channel, then persist status (sent/failed) and sent_at. Returns true if the
     * message was accepted by the gateway.
     */
    public static function dispatch(Notification $n): bool
    {
        if ($n->status === Notification::STATUS_SENT) {
            return true; // idempotent: already delivered
        }

        // A freshly loaded row may carry payload as a JSON string; decode it.
        $payload = is_array($n->payload)
            ? $n->payload
            : (is_string($n->payload) ? (json_decode($n->payload, true) ?: []) : []);

        $text = self::render($n->template, $payload);
        $ok = false;

        if ($n->channel === Notification::CHANNEL_TELEGRAM) {
            $chatId = self::telegramChatFor($n->client_id);
            $ok = $chatId !== null && TelegramSender::send($chatId, $text);
        } elseif ($n->channel === Notification::CHANNEL_SMS) {
            $phone = self::phoneFor($n->client_id);
            $ok = $phone !== null && SmsSender::send($phone, $text);
        } else {
            Yii::warning("Unknown notification channel '{$n->channel}' (id {$n->id}).", 'notify');
        }

        $n->status = $ok ? Notification::STATUS_SENT : Notification::STATUS_FAILED;
        $n->sent_at = $ok ? time() : null;
        // status/sent_at are internal transitions; skip validation to avoid
        // re-running business rules on an already-persisted row.
        $n->save(false, ['status', 'sent_at']);

        return $ok;
    }

    /** Verified Telegram chat id bound to a client, or null. */
    private static function telegramChatFor(?int $clientId): ?int
    {
        if ($clientId === null) {
            return null;
        }
        $link = TelegramLink::find()
            ->where(['client_id' => $clientId])
            ->andWhere(['not', ['verified_at' => null]])
            ->orderBy(['id' => SORT_DESC])
            ->one();

        return $link !== null ? (int) $link->tg_chat_id : null;
    }

    /** Phone number for a client (SMS fallback), or null. */
    private static function phoneFor(?int $clientId): ?string
    {
        if ($clientId === null) {
            return null;
        }
        $client = Client::findOne($clientId);
        return $client !== null && $client->phone !== '' ? (string) $client->phone : null;
    }

    /**
     * Render a message from a template id and its payload variables. Uses simple
     * server-side templates (UI copy is Uzbek/Russian client-facing). Unknown
     * templates fall back to a readable key: value dump so nothing is lost.
     */
    public static function render(string $template, array $payload): string
    {
        $when = (string) ($payload['starts_at_local'] ?? $payload['starts_at'] ?? '');
        $service = (string) ($payload['service'] ?? '');
        $business = (string) ($payload['business'] ?? '');

        switch ($template) {
            case 'reminder':
                $line = 'Eslatma: sizda ' . ($when !== '' ? $when . ' da ' : '') . 'navbat bor';
                if ($service !== '') {
                    $line .= ' (' . $service . ')';
                }
                if ($business !== '') {
                    $line .= ' — ' . $business;
                }
                return $line . '.';

            case 'confirmation':
                $line = 'Navbatingiz tasdiqlandi';
                if ($when !== '') {
                    $line .= ': ' . $when;
                }
                if ($business !== '') {
                    $line .= ' — ' . $business;
                }
                return $line . '.';

            case 'cancellation':
                $line = 'Navbatingiz bekor qilindi';
                if ($when !== '') {
                    $line .= ' (' . $when . ')';
                }
                return $line . '.';

            default:
                if (isset($payload['text']) && is_string($payload['text'])) {
                    return $payload['text'];
                }
                $parts = [];
                foreach ($payload as $k => $v) {
                    if (is_scalar($v)) {
                        $parts[] = $k . ': ' . $v;
                    }
                }
                return $parts === [] ? $template : implode(', ', $parts);
        }
    }
}
