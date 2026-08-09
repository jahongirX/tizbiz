<?php

namespace api\modules\billing\controllers;

use api\modules\billing\services\ClickGateway;
use api\modules\billing\services\PaymeGateway;
use common\models\Appointment;
use common\models\Transaction;
use common\rest\Controller;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\ConflictHttpException;
use yii\web\NotFoundHttpException;
use yii\web\UnprocessableEntityHttpException;

/**
 * Deposit initiation and refund flow.
 *
 * POST /v1/payments/deposit         public (consumer booking page) — creates a
 *                                   deposit Transaction and returns a provider
 *                                   init payload (Payme checkout URL / Click params).
 * POST /v1/payments/<id>/refund     business_owner/business_admin — refund a paid deposit.
 */
class PaymentController extends Controller
{
    protected function authOptional(): array
    {
        return ['deposit'];
    }

    public function actionDeposit()
    {
        $appointmentId = (int) $this->body('appointment_id');
        $provider = (string) $this->body('provider');

        if ($appointmentId <= 0) {
            throw new BadRequestHttpException('appointment_id talab qilinadi.');
        }
        if (!in_array($provider, [Transaction::PROVIDER_PAYME, Transaction::PROVIDER_CLICK], true)) {
            throw new BadRequestHttpException('provider payme yoki click bo\'lishi kerak.');
        }

        $appointment = Appointment::findOne($appointmentId);
        if ($appointment === null) {
            throw new NotFoundHttpException('Bron topilmadi.');
        }

        // Deposit amount: appointment override, else the service default.
        $amount = $appointment->deposit_tiyin;
        if ($amount === null) {
            $service = $appointment->service ?? null;
            $amount = $service !== null ? $service->deposit_tiyin : null;
        }
        if ($amount === null || (int) $amount <= 0) {
            throw new UnprocessableEntityHttpException('Bu bron uchun oldindan to\'lov talab qilinmaydi.');
        }

        // Idempotency: replay the same init for a repeated key.
        $idempotencyKey = Yii::$app->request->headers->get('Idempotency-Key') ?: null;
        if ($idempotencyKey !== null) {
            $existing = Transaction::find()->where([
                'idempotency_key' => $idempotencyKey,
                'business_id' => (int) $appointment->business_id,
                'appointment_id' => $appointmentId,
                'provider' => $provider,
            ])->one();
            if ($existing !== null) {
                return $this->initPayload($existing);
            }
        } else {
            $idempotencyKey = 'dep_' . bin2hex(random_bytes(16));
        }

        $tx = new Transaction();
        $tx->business_id = (int) $appointment->business_id; // derived; no tenant on public endpoint
        $tx->appointment_id = $appointmentId;
        $tx->provider = $provider;
        $tx->amount_tiyin = (int) $amount;
        $tx->type = Transaction::TYPE_DEPOSIT;
        $tx->status = Transaction::STATUS_CREATED;
        $tx->idempotency_key = $idempotencyKey;
        if (!$tx->save()) {
            return $this->fail422($tx);
        }

        return $this->created($this->initPayload($tx));
    }

    public function actionRefund(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        // Tenant-scoped: only the caller's own business transactions resolve.
        $tx = Transaction::findOne($id);
        if ($tx === null) {
            throw new NotFoundHttpException('Tranzaksiya topilmadi.');
        }
        if ($tx->type !== Transaction::TYPE_DEPOSIT || $tx->status !== Transaction::STATUS_PAID) {
            throw new ConflictHttpException('Faqat to\'langan oldindan to\'lovni qaytarish mumkin.');
        }

        // Record the refund as its own Transaction. The external PSP refund call
        // is a stub here; on success the row would move created -> pending -> refunded.
        $refund = new Transaction();
        $refund->business_id = Yii::$app->tenant->require();
        $refund->appointment_id = $tx->appointment_id;
        $refund->provider = $tx->provider;
        $refund->amount_tiyin = $tx->amount_tiyin;
        $refund->type = Transaction::TYPE_REFUND;
        // Do NOT copy the deposit's external_id: two rows sharing (provider, external_id)
        // break webhook lookups. Leave the refund row's external_id null.
        $refund->idempotency_key = 'ref_' . $tx->id . '_' . bin2hex(random_bytes(8));

        // Stubbed external refund; a real gateway call would go here.
        $refund->status = Transaction::STATUS_REFUNDED;
        if (!$refund->save()) {
            return $this->fail422($refund);
        }

        // Mark the original deposit refunded.
        $tx->status = Transaction::STATUS_REFUNDED;
        $tx->save(false);

        return $this->created($refund);
    }

    /** Provider-specific init payload for a deposit transaction. */
    private function initPayload(Transaction $tx): array
    {
        $returnUrl = (string) $this->body('return_url', '');

        if ($tx->provider === Transaction::PROVIDER_PAYME) {
            $gateway = new PaymeGateway();
            return [
                'transaction' => $tx,
                'provider' => Transaction::PROVIDER_PAYME,
                'checkout_url' => $gateway->checkoutUrl($tx),
            ];
        }

        $gateway = new ClickGateway();
        return [
            'transaction' => $tx,
            'provider' => Transaction::PROVIDER_CLICK,
            'click' => $gateway->payInit($tx, $returnUrl !== '' ? $returnUrl : null),
        ];
    }
}
