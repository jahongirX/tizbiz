<?php

namespace api\modules\billing\services;

use common\models\Transaction;

/**
 * Payme (Paycom) Merchant API gateway.
 *
 * Holds the JSON-RPC protocol logic and error codes; the controller stays thin,
 * only verifying the HTTP Basic auth header and forwarding {method, params}.
 *
 * Our Transaction.id is the Payme "account.order_id". The Payme transaction id
 * (params.id) is stored in Transaction.external_id. All money is in tiyin.
 *
 * Config (env, test defaults):
 *   PAYME_MERCHANT_ID, PAYME_KEY (Basic auth password: base64('Paycom:'+PAYME_KEY)).
 *
 * Note: the transactions table has no dedicated create/perform/cancel time
 * columns, so those timestamps are derived from created_at/updated_at (ms).
 * They are deterministic per row, which keeps CheckTransaction idempotent.
 */
class PaymeGateway
{
    // Payme error codes.
    public const ERR_AUTH = -32504;               // invalid merchant authorization
    public const ERR_METHOD_NOT_FOUND = -32601;   // unknown RPC method
    public const ERR_INVALID_AMOUNT = -31001;     // amount does not match order
    public const ERR_TX_NOT_FOUND = -31003;       // Payme transaction not found
    public const ERR_CANNOT_PERFORM = -31008;     // order in a state that forbids the op
    public const ERR_ORDER_NOT_FOUND = -31050;    // account.order_id does not resolve

    // Payme transaction states.
    public const STATE_CREATED = 1;
    public const STATE_COMPLETED = 2;
    public const STATE_CANCELED = -1;             // canceled while pending
    public const STATE_CANCELED_AFTER_COMPLETE = -2; // canceled/refunded after paid

    public static function merchantId(): string
    {
        return getenv('PAYME_MERCHANT_ID') ?: 'test_merchant';
    }

    public static function key(): string
    {
        return getenv('PAYME_KEY') ?: 'test_key';
    }

    /** Expected value of the HTTP Authorization header. */
    public function expectedAuthHeader(): string
    {
        return 'Basic ' . base64_encode('Paycom:' . self::key());
    }

    /** Constant-time verification of the merchant Basic auth header. */
    public function verifyAuth(?string $header): bool
    {
        if ($header === null || $header === '') {
            return false;
        }
        return hash_equals($this->expectedAuthHeader(), $header);
    }

    /**
     * Build the hosted-checkout URL for a freshly created deposit transaction.
     * base64(m=MERCHANT;ac.order_id=TX_ID;a=AMOUNT) appended to the checkout host.
     */
    public function checkoutUrl(Transaction $tx): string
    {
        $payload = sprintf(
            'm=%s;ac.order_id=%d;a=%d',
            self::merchantId(),
            (int) $tx->id,
            (int) $tx->amount_tiyin
        );
        return 'https://checkout.paycom.uz/' . base64_encode($payload);
    }

    /**
     * Dispatch a JSON-RPC method and return the inner response body, i.e. either
     * ['result' => [...]] or ['error' => ['code' => .., 'message' => ..]].
     * The controller attaches the request id.
     */
    public function handle(string $method, array $params): array
    {
        switch ($method) {
            case 'CheckPerformTransaction':
                return $this->checkPerform($params);
            case 'CreateTransaction':
                return $this->createTransaction($params);
            case 'PerformTransaction':
                return $this->performTransaction($params);
            case 'CancelTransaction':
                return $this->cancelTransaction($params);
            case 'CheckTransaction':
                return $this->checkTransaction($params);
            case 'GetStatement':
                return $this->getStatement($params);
            default:
                return $this->error(self::ERR_METHOD_NOT_FOUND, 'Metod topilmadi.');
        }
    }

    // --- Methods ---

    private function checkPerform(array $params): array
    {
        $orderId = $this->orderId($params);
        $tx = $orderId !== null ? Transaction::findOne($orderId) : null;
        if ($tx === null || $tx->type !== Transaction::TYPE_DEPOSIT) {
            return $this->error(self::ERR_ORDER_NOT_FOUND, 'Buyurtma topilmadi.', 'order_id');
        }
        if (!in_array($tx->status, [Transaction::STATUS_CREATED, Transaction::STATUS_PENDING], true)) {
            return $this->error(self::ERR_CANNOT_PERFORM, 'Buyurtma to\'lov qilinadigan holatda emas.');
        }
        if ((int) $params['amount'] !== (int) $tx->amount_tiyin) {
            return $this->error(self::ERR_INVALID_AMOUNT, 'Summa noto\'g\'ri.');
        }
        return ['result' => ['allow' => true]];
    }

    private function createTransaction(array $params): array
    {
        $orderId = $this->orderId($params);
        $tx = $orderId !== null ? Transaction::findOne($orderId) : null;
        if ($tx === null || $tx->type !== Transaction::TYPE_DEPOSIT) {
            return $this->error(self::ERR_ORDER_NOT_FOUND, 'Buyurtma topilmadi.', 'order_id');
        }
        if ((int) $params['amount'] !== (int) $tx->amount_tiyin) {
            return $this->error(self::ERR_INVALID_AMOUNT, 'Summa noto\'g\'ri.');
        }
        $paymeId = (string) ($params['id'] ?? '');

        // Idempotent: same Payme id already bound and still pending -> replay state.
        if ($tx->external_id === $paymeId && $tx->status === Transaction::STATUS_PENDING) {
            return ['result' => [
                'create_time' => $this->ms($tx->created_at),
                'transaction' => (string) $tx->id,
                'state' => self::STATE_CREATED,
            ]];
        }

        // A different transaction is already bound, or the order is finalized.
        if ($tx->external_id !== null || $tx->status !== Transaction::STATUS_CREATED) {
            return $this->error(self::ERR_CANNOT_PERFORM, 'Buyurtmada allaqachon jarayondagi tranzaksiya mavjud.');
        }

        $tx->external_id = $paymeId;
        $tx->status = Transaction::STATUS_PENDING;
        $tx->save(false);

        return ['result' => [
            'create_time' => $this->ms($tx->created_at),
            'transaction' => (string) $tx->id,
            'state' => self::STATE_CREATED,
        ]];
    }

    private function performTransaction(array $params): array
    {
        $tx = $this->byPaymeId($params);
        if ($tx === null) {
            return $this->error(self::ERR_TX_NOT_FOUND, 'Tranzaksiya topilmadi.');
        }
        if ($tx->status === Transaction::STATUS_PAID) {
            return ['result' => [
                'transaction' => (string) $tx->id,
                'perform_time' => $this->ms($tx->updated_at),
                'state' => self::STATE_COMPLETED,
            ]];
        }
        if ($tx->status !== Transaction::STATUS_PENDING) {
            return $this->error(self::ERR_CANNOT_PERFORM, 'Tranzaksiyani amalga oshirib bo\'lmaydi.');
        }
        $tx->status = Transaction::STATUS_PAID;
        $tx->save(false);
        $tx->markAppointmentPaid();

        return ['result' => [
            'transaction' => (string) $tx->id,
            'perform_time' => $this->ms($tx->updated_at),
            'state' => self::STATE_COMPLETED,
        ]];
    }

    private function cancelTransaction(array $params): array
    {
        $tx = $this->byPaymeId($params);
        if ($tx === null) {
            return $this->error(self::ERR_TX_NOT_FOUND, 'Tranzaksiya topilmadi.');
        }

        if (in_array($tx->status, [Transaction::STATUS_CANCELED, Transaction::STATUS_REFUNDED], true)) {
            return ['result' => [
                'transaction' => (string) $tx->id,
                'cancel_time' => $this->ms($tx->updated_at),
                'state' => $this->cancelState($tx),
            ]];
        }

        $tx->status = $tx->status === Transaction::STATUS_PAID
            ? Transaction::STATUS_REFUNDED
            : Transaction::STATUS_CANCELED;
        $tx->save(false);

        return ['result' => [
            'transaction' => (string) $tx->id,
            'cancel_time' => $this->ms($tx->updated_at),
            'state' => $this->cancelState($tx),
        ]];
    }

    private function checkTransaction(array $params): array
    {
        $tx = $this->byPaymeId($params);
        if ($tx === null) {
            return $this->error(self::ERR_TX_NOT_FOUND, 'Tranzaksiya topilmadi.');
        }
        return ['result' => $this->stateReport($tx)];
    }

    private function getStatement(array $params): array
    {
        $from = (int) floor(((int) ($params['from'] ?? 0)) / 1000);
        $to = (int) ceil(((int) ($params['to'] ?? 0)) / 1000);

        $rows = Transaction::find()
            ->where(['provider' => Transaction::PROVIDER_PAYME])
            ->andWhere(['not', ['external_id' => null]])
            ->andWhere(['between', 'created_at', $from, $to])
            ->all();

        $transactions = [];
        foreach ($rows as $tx) {
            $transactions[] = [
                'id' => (string) $tx->external_id,
                'time' => $this->ms($tx->created_at),
                'amount' => (int) $tx->amount_tiyin,
                'account' => ['order_id' => (string) $tx->id],
                'create_time' => $this->ms($tx->created_at),
                'perform_time' => $tx->status === Transaction::STATUS_PAID ? $this->ms($tx->updated_at) : 0,
                'cancel_time' => in_array($tx->status, [Transaction::STATUS_CANCELED, Transaction::STATUS_REFUNDED], true)
                    ? $this->ms($tx->updated_at) : 0,
                'transaction' => (string) $tx->id,
                'state' => $this->stateOf($tx),
                'reason' => null,
            ];
        }

        return ['result' => ['transactions' => $transactions]];
    }

    // --- Helpers ---

    private function stateReport(Transaction $tx): array
    {
        $paid = $tx->status === Transaction::STATUS_PAID;
        $canceled = in_array($tx->status, [Transaction::STATUS_CANCELED, Transaction::STATUS_REFUNDED], true);
        return [
            'create_time' => $this->ms($tx->created_at),
            'perform_time' => $paid ? $this->ms($tx->updated_at) : 0,
            'cancel_time' => $canceled ? $this->ms($tx->updated_at) : 0,
            'transaction' => (string) $tx->id,
            'state' => $this->stateOf($tx),
            'reason' => null,
        ];
    }

    private function stateOf(Transaction $tx): int
    {
        switch ($tx->status) {
            case Transaction::STATUS_PAID:
                return self::STATE_COMPLETED;
            case Transaction::STATUS_CANCELED:
                return self::STATE_CANCELED;
            case Transaction::STATUS_REFUNDED:
                return self::STATE_CANCELED_AFTER_COMPLETE;
            default:
                return self::STATE_CREATED;
        }
    }

    private function cancelState(Transaction $tx): int
    {
        return $tx->status === Transaction::STATUS_REFUNDED
            ? self::STATE_CANCELED_AFTER_COMPLETE
            : self::STATE_CANCELED;
    }

    private function orderId(array $params): ?int
    {
        $account = $params['account'] ?? [];
        $orderId = is_array($account) ? ($account['order_id'] ?? null) : null;
        return $orderId !== null && $orderId !== '' ? (int) $orderId : null;
    }

    private function byPaymeId(array $params): ?Transaction
    {
        $id = (string) ($params['id'] ?? '');
        if ($id === '') {
            return null;
        }
        return Transaction::find()
            ->where(['provider' => Transaction::PROVIDER_PAYME, 'external_id' => $id])
            ->one();
    }

    private function ms($seconds): int
    {
        return ((int) $seconds) * 1000;
    }

    private function error(int $code, string $message, ?string $data = null): array
    {
        $error = ['code' => $code, 'message' => $message];
        if ($data !== null) {
            $error['data'] = $data;
        }
        return ['error' => $error];
    }
}
