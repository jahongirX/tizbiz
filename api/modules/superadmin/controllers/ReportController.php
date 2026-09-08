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

        return [
            'leads' => $leads,
            'leads_total' => $leadsTotal,
            'conversion' => $leadsTotal > 0 ? (int) round($leads['won'] / $leadsTotal * 100) : 0,
            'sales_count' => (int) SmsSale::find()->count(),
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
