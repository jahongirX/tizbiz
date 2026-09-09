<?php

namespace api\modules\superadmin\controllers;

use common\models\SmsAccount;
use common\models\SmsLead;
use common\models\SmsMessage;
use common\models\SmsRecipient;
use common\models\SmsSale;
use common\models\User;

/**
 * Superadmin dashboard numbers: leads funnel, sales/revenue, account & SMS
 * volume, top accounts, recipient base, conversion.
 */
class ReportController extends BaseController
{
    public function actionSummary(): array
    {
        $monthStart = strtotime(date('Y-m-01 00:00:00'));
        $dayStart = strtotime('today');

        $leads = [];
        foreach (SmsLead::STATUSES as $st) {
            $leads[$st] = (int) SmsLead::find()->where(['status' => $st])->count();
        }
        $leadsTotal = array_sum($leads);

        $topRows = SmsMessage::find()
            ->select(['user_id', 'cnt' => 'COUNT(*)'])
            ->where(['>=', 'created_at', $monthStart])
            ->groupBy('user_id')
            ->orderBy(['cnt' => SORT_DESC])
            ->limit(5)
            ->asArray()
            ->all();
        $top = [];
        foreach ($topRows as $r) {
            $u = User::findOne($r['user_id']);
            $top[] = [
                'name' => $u ? ($u->name ?: $u->phone) : ('user #' . $r['user_id']),
                'count' => (int) $r['cnt'],
            ];
        }

        // Contracts (sales) nearing expiry — the renewal reminder the superadmin
        // sees on login: within 30 days ahead, plus anything lapsed in the last week.
        $now = time();
        $soon = $now + 30 * 86400;
        $expiringRows = SmsSale::find()
            ->where(['not', ['ends_at' => null]])
            ->andWhere(['<=', 'ends_at', $soon])
            ->andWhere(['>=', 'ends_at', $now - 7 * 86400])
            ->orderBy(['ends_at' => SORT_ASC])
            ->limit(50)
            ->all();
        $expiring = [];
        foreach ($expiringRows as $c) {
            $expiring[] = [
                'id' => (int) $c->id,
                'name' => $c->name,
                'phone' => $c->phone,
                'tariff' => $c->tariff,
                'amount' => (int) $c->amount,
                'ends_at' => (int) $c->ends_at,
                'days_left' => $c->daysLeft(),
            ];
        }

        return [
            'leads' => $leads,
            'leads_total' => $leadsTotal,
            'conversion' => $leadsTotal > 0 ? (int) round($leads['won'] / $leadsTotal * 100) : 0,
            'sales_count' => (int) SmsSale::find()->count(),
            'contracts_active' => (int) SmsSale::find()->where(['>', 'ends_at', $now])->count(),
            'contracts_expiring' => $expiring,
            'revenue_total' => (int) SmsSale::find()->sum('amount'),
            'revenue_month' => (int) SmsSale::find()->where(['>=', 'created_at', $monthStart])->sum('amount'),
            'accounts_total' => (int) SmsAccount::find()->count(),
            'accounts_active' => (int) SmsAccount::find()->where(['is_active' => 1])->count(),
            'sms_total' => (int) SmsMessage::find()->count(),
            'sms_month' => (int) SmsMessage::find()->where(['>=', 'created_at', $monthStart])->count(),
            'sms_today' => (int) SmsMessage::find()->where(['>=', 'created_at', $dayStart])->count(),
            'recipients' => (int) SmsRecipient::find()->count(),
            'top_accounts' => $top,
        ];
    }
}
