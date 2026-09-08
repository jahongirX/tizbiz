<?php

namespace api\modules\superadmin\controllers;

use common\models\SmsLead;
use common\models\SmsSale;

/**
 * Manual subscription sales (superadmin records a paid tariff). Feeds revenue
 * reports. Recording a sale from a lead marks that lead as won.
 */
class SaleController extends BaseController
{
    public function actionIndex(): array
    {
        return SmsSale::find()->orderBy(['created_at' => SORT_DESC])->limit(500)->all();
    }

    public function actionCreate()
    {
        $sale = new SmsSale();
        $sale->lead_id = self::intOrNull($this->body('lead_id'));
        $sale->account_id = self::intOrNull($this->body('account_id'));
        $sale->name = self::clip($this->body('name'), 160);
        $sale->phone = self::clip($this->body('phone'), 32);
        $sale->tariff = self::clip($this->body('tariff'), 20);
        $sale->amount = max(0, (int) $this->body('amount', 0));
        $sale->period_months = max(1, (int) ($this->body('period_months') ?: 12));
        $sale->starts_at = time();
        $sale->ends_at = strtotime('+' . $sale->period_months . ' months');
        $sale->note = self::clip($this->body('note'), 500);
        if (!$sale->save()) {
            return $this->fail422($sale);
        }
        if ($sale->lead_id) {
            $lead = SmsLead::findOne($sale->lead_id);
            if ($lead !== null) {
                $lead->status = 'won';
                $lead->save(false);
            }
        }
        return $this->created($sale);
    }

    public function actionDelete(int $id): array
    {
        $sale = SmsSale::findOne($id);
        if ($sale !== null) {
            $sale->delete();
        }
        return ['deleted' => true];
    }

    private static function intOrNull($v): ?int
    {
        return ($v === null || $v === '') ? null : (int) $v;
    }

    private static function clip($v, int $max): ?string
    {
        $s = trim((string) ($v ?? ''));
        return $s === '' ? null : mb_substr($s, 0, $max);
    }
}
