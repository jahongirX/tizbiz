<?php

namespace api\modules\notify\controllers;

use common\models\TelegramLink;
use common\rest\Controller;
use Yii;

/**
 * Receives Telegram Bot API webhook updates.
 *
 * The only interactive command handled is `/start <token>`, sent when a user
 * opens `https://t.me/<bot>?start=<token>`. The token is the signed reference
 * produced by {@see TelegramLink::makeStartToken()} and identifies the client (or
 * user) to bind to this chat. We create/verify the link and reply once.
 *
 * The endpoint is public (Telegram calls it) and always answers 200 quickly so
 * Telegram does not retry; failures are logged, never surfaced.
 */
class TelegramWebhookController extends Controller
{
    protected function authOptional(): array
    {
        return ['update'];
    }

    public function actionUpdate(): array
    {
        // Verify Telegram's webhook secret when one is configured. In dev (no
        // secret set) the endpoint keeps working unauthenticated.
        $secret = getenv('TELEGRAM_WEBHOOK_SECRET');
        if ($secret !== false && $secret !== '') {
            $provided = (string) Yii::$app->request->getHeaders()->get('X-Telegram-Bot-Api-Secret-Token', '');
            if (!hash_equals((string) $secret, $provided)) {
                Yii::warning('Telegram webhook secret mismatch; update ignored.', 'notify');
                return ['ok' => true, 'ignored' => true];
            }
        }

        try {
            $update = Yii::$app->request->getBodyParams();
            $this->handle(is_array($update) ? $update : []);
        } catch (\Throwable $e) {
            // Never fail the webhook — Telegram would retry indefinitely.
            Yii::error('Telegram webhook error: ' . $e->getMessage(), 'notify');
        }
        return ['ok' => true];
    }

    private function handle(array $update): void
    {
        $message = $update['message'] ?? $update['edited_message'] ?? null;
        if (!is_array($message)) {
            return;
        }

        $chatId = isset($message['chat']['id']) ? (int) $message['chat']['id'] : 0;
        $text = isset($message['text']) ? trim((string) $message['text']) : '';
        if ($chatId === 0 || $text === '') {
            return;
        }

        // Only /start <token> triggers linking.
        if (!preg_match('/^\/start(?:@\w+)?\s+(\S+)/', $text, $m)) {
            return;
        }

        $parsed = TelegramLink::parseStartToken($m[1]);
        if ($parsed === null) {
            Yii::warning("Telegram /start with invalid token from chat $chatId.", 'notify');
            return;
        }

        $this->linkChat($chatId, $parsed['client_id'], $parsed['user_id']);
    }

    /**
     * Create or update the (chat -> client/user) binding and mark it verified.
     * Idempotent: a repeated /start for the same chat + target does not duplicate.
     */
    private function linkChat(int $chatId, ?int $clientId, ?int $userId): void
    {
        $condition = ['tg_chat_id' => $chatId];
        if ($clientId !== null) {
            $condition['client_id'] = $clientId;
        }
        if ($userId !== null) {
            $condition['user_id'] = $userId;
        }

        $link = TelegramLink::find()->where($condition)->one();
        if ($link === null) {
            $link = new TelegramLink();
            $link->tg_chat_id = $chatId;
            $link->client_id = $clientId;
            $link->user_id = $userId;
        }
        $link->verified_at = time();

        if (!$link->save()) {
            Yii::warning('Failed to save TelegramLink: ' . json_encode($link->getErrors()), 'notify');
        }
    }
}
