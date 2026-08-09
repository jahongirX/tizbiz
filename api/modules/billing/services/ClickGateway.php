<?php

namespace api\modules\billing\services;

use common\models\Transaction;

/**
 * Click Merchant API gateway (Prepare + Complete).
 *
 * Holds the protocol logic, signature check and error codes; the controller is
 * thin. Our Transaction.id is Click's merchant_trans_id and also serves as the
 * merchant_prepare_id / merchant_confirm_id we echo back. The Click transaction
 * id (click_trans_id) is stored in Transaction.external_id. Money is in tiyin.
 *
 * Config (env, test defaults):
 *   CLICK_SERVICE_ID, CLICK_MERCHANT_ID, CLICK_SECRET_KEY.
 */
class ClickGateway
{
    public const ACTION_PREPARE = 0;
    public const ACTION_COMPLETE = 1;

    // Click error codes.
    public const ERR_OK = 0;
    public const ERR_SIGN = -1;             // sign check failed
    public const ERR_AMOUNT = -2;           // incorrect amount
    public const ERR_ACTION = -3;           // action not found
    public const ERR_ALREADY_PAID = -4;     // already paid
    public const ERR_ORDER_NOT_FOUND = -5;  // order/user does not exist
    public const ERR_TX_NOT_FOUND = -6;     // transaction does not exist
    public const ERR_CANCELED = -9;         // transaction canceled

    public static function serviceId(): string
    {
        return getenv('CLICK_SERVICE_ID') ?: '0';
    }

    public static function merchantId(): string
    {
        return getenv('CLICK_MERCHANT_ID') ?: '0';
    }

    public static function secretKey(): string
    {
        return getenv('CLICK_SECRET_KEY') ?: 'test_secret';
    }

    /**
     * Build the hosted pay URL + params for a freshly created deposit.
     */
    public function payInit(Transaction $tx, ?string $returnUrl = null): array
    {
        $params = [
            'service_id' => (int) self::serviceId(),
            'merchant_id' => (int) self::merchantId(),
            'amount' => (int) $tx->amount_tiyin,
            'transaction_param' => (string) $tx->id,
        ];
        if ($returnUrl !== null && $returnUrl !== '') {
            $params['return_url'] = $returnUrl;
        }
        $params['pay_url'] = 'https://my.click.uz/services/pay?' . http_build_query($params);
        return $params;
    }

    /**
     * Dispatch a webhook request (already decoded body) and return the exact
     * Click response array. Signature is verified here.
     */
    public function handle(array $request): array
    {
        $action = isset($request['action']) ? (int) $request['action'] : null;

        if (!$this->verifySign($request)) {
            return $this->respond($request, self::ERR_SIGN, 'Imzo tekshiruvi muvaffaqiyatsiz');
        }
        if ($action === self::ACTION_PREPARE) {
            return $this->prepare($request);
        }
        if ($action === self::ACTION_COMPLETE) {
            return $this->complete($request);
        }
        return $this->respond($request, self::ERR_ACTION, 'Amal topilmadi');
    }

    /**
     * sign_string = md5(click_trans_id + service_id + SECRET_KEY + merchant_trans_id
     *   + [merchant_prepare_id (complete only)] + amount + action + sign_time)
     */
    public function verifySign(array $request): bool
    {
        $provided = (string) ($request['sign_string'] ?? '');
        if ($provided === '') {
            return false;
        }
        $parts = [
            (string) ($request['click_trans_id'] ?? ''),
            (string) ($request['service_id'] ?? ''),
            self::secretKey(),
            (string) ($request['merchant_trans_id'] ?? ''),
        ];
        if ((int) ($request['action'] ?? -1) === self::ACTION_COMPLETE) {
            $parts[] = (string) ($request['merchant_prepare_id'] ?? '');
        }
        $parts[] = (string) ($request['amount'] ?? '');
        $parts[] = (string) ($request['action'] ?? '');
        $parts[] = (string) ($request['sign_time'] ?? '');

        $expected = md5(implode('', $parts));
        return hash_equals($expected, $provided);
    }

    private function prepare(array $request): array
    {
        $tx = $this->findOrder($request);
        if ($tx === null) {
            return $this->respond($request, self::ERR_ORDER_NOT_FOUND, 'Buyurtma topilmadi');
        }
        if ($tx->status === Transaction::STATUS_PAID) {
            return $this->respond($request, self::ERR_ALREADY_PAID, 'Allaqachon to\'langan');
        }
        if (in_array($tx->status, [Transaction::STATUS_CANCELED, Transaction::STATUS_REFUNDED], true)) {
            return $this->respond($request, self::ERR_CANCELED, 'Tranzaksiya bekor qilingan');
        }
        if (!$this->amountMatches($request, $tx)) {
            return $this->respond($request, self::ERR_AMOUNT, 'Summa noto\'g\'ri');
        }

        $tx->external_id = (string) ($request['click_trans_id'] ?? $tx->external_id);
        if ($tx->status === Transaction::STATUS_CREATED) {
            $tx->status = Transaction::STATUS_PENDING;
        }
        $tx->save(false);

        return $this->respond($request, self::ERR_OK, 'Success');
    }

    private function complete(array $request): array
    {
        $tx = $this->findOrder($request);
        if ($tx === null) {
            return $this->respond($request, self::ERR_TX_NOT_FOUND, 'Tranzaksiya topilmadi');
        }
        // merchant_prepare_id must match the id we returned on Prepare (our tx id).
        if ((string) ($request['merchant_prepare_id'] ?? '') !== (string) $tx->id) {
            return $this->respond($request, self::ERR_TX_NOT_FOUND, 'Tranzaksiya topilmadi');
        }
        if ($tx->status === Transaction::STATUS_PAID) {
            // Idempotent replay.
            return $this->respond($request, self::ERR_OK, 'Success');
        }
        if (in_array($tx->status, [Transaction::STATUS_CANCELED, Transaction::STATUS_REFUNDED], true)) {
            return $this->respond($request, self::ERR_CANCELED, 'Tranzaksiya bekor qilingan');
        }

        // Click signals its own failure via a negative error field on complete.
        if ((int) ($request['error'] ?? 0) < 0) {
            $tx->status = Transaction::STATUS_CANCELED;
            $tx->save(false);
            return $this->respond($request, self::ERR_CANCELED, 'Tranzaksiya bekor qilingan');
        }
        if (!$this->amountMatches($request, $tx)) {
            return $this->respond($request, self::ERR_AMOUNT, 'Summa noto\'g\'ri');
        }

        $tx->status = Transaction::STATUS_PAID;
        $tx->save(false);
        $tx->markAppointmentPaid();

        return $this->respond($request, self::ERR_OK, 'Success');
    }

    private function findOrder(array $request): ?Transaction
    {
        $orderId = (int) ($request['merchant_trans_id'] ?? 0);
        if ($orderId <= 0) {
            return null;
        }
        $tx = Transaction::find()
            ->where(['id' => $orderId, 'provider' => Transaction::PROVIDER_CLICK])
            ->one();
        // Only a deposit is a payable order; mirror PaymeGateway's guard.
        if ($tx === null || $tx->type !== Transaction::TYPE_DEPOSIT) {
            return null;
        }
        return $tx;
    }

    private function amountMatches(array $request, Transaction $tx): bool
    {
        // Amount is sent in tiyin; tolerate a decimal string form.
        return (int) round((float) ($request['amount'] ?? -1)) === (int) $tx->amount_tiyin;
    }

    private function respond(array $request, int $error, string $note): array
    {
        $out = [
            'click_trans_id' => (int) ($request['click_trans_id'] ?? 0),
            'merchant_trans_id' => (string) ($request['merchant_trans_id'] ?? ''),
        ];
        $action = isset($request['action']) ? (int) $request['action'] : null;
        // Echo our confirmation id only on success.
        $ourId = (string) ($request['merchant_trans_id'] ?? '');
        if ($action === self::ACTION_COMPLETE) {
            $out['merchant_confirm_id'] = $error === self::ERR_OK ? $ourId : null;
        } else {
            $out['merchant_prepare_id'] = $error === self::ERR_OK ? $ourId : null;
        }
        $out['error'] = $error;
        $out['error_note'] = $note;
        return $out;
    }
}
