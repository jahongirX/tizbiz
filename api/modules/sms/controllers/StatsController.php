<?php

namespace api\modules\sms\controllers;

use common\models\SmsDevice;
use common\models\SmsMessage;

/**
 * Dashboard counters for the account: totals by status, today's volume, and
 * device counts.
 */
class StatsController extends BaseController
{
    public function actionIndex(): array
    {
        $uid = $this->uid();
        $base = static fn () => SmsMessage::find()->where(['user_id' => $uid]);

        $startOfDay = strtotime('today');

        return [
            'messages' => [
                'total' => (int) $base()->count(),
                'sent' => (int) $base()->andWhere(['status' => SmsMessage::STATUS_SENT])->count(),
                'failed' => (int) $base()->andWhere(['status' => SmsMessage::STATUS_FAILED])->count(),
                'pending' => (int) $base()->andWhere(['status' => SmsMessage::STATUS_PENDING])->count(),
                'today' => (int) $base()->andWhere(['>=', 'created_at', $startOfDay])->count(),
            ],
            'devices' => [
                'total' => (int) SmsDevice::find()->where(['user_id' => $uid])->count(),
                'active' => (int) SmsDevice::find()->where(['user_id' => $uid, 'is_active' => true])->count(),
                'online' => (int) SmsDevice::find()->where(['user_id' => $uid, 'status' => SmsDevice::STATUS_ONLINE])->count(),
            ],
        ];
    }
}
