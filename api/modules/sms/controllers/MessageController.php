<?php

namespace api\modules\sms\controllers;

use common\models\SmsMessage;
use Yii;

/**
 * Outbound message log for the account, newest first. Filters: status, phone,
 * device_id, free text (q). Paginated via limit/offset.
 */
class MessageController extends BaseController
{
    public function actionIndex(): array
    {
        $req = Yii::$app->request;
        $q = SmsMessage::find()->where(['user_id' => $this->uid()]);

        $status = (string) $req->get('status', '');
        if ($status !== '' && in_array($status, SmsMessage::STATUSES, true)) {
            $q->andWhere(['status' => $status]);
        }
        if (($phone = trim((string) $req->get('phone', ''))) !== '') {
            $q->andWhere(['like', 'phone', $phone]);
        }
        if (($deviceId = (int) $req->get('device_id', 0)) > 0) {
            $q->andWhere(['device_id' => $deviceId]);
        }
        if (($text = trim((string) $req->get('q', ''))) !== '') {
            $q->andWhere(['like', 'text', $text]);
        }

        $limit = min(200, max(1, (int) $req->get('limit', 50)));
        $offset = max(0, (int) $req->get('offset', 0));
        $total = (int) $q->count();

        $items = $q->orderBy(['id' => SORT_DESC])->limit($limit)->offset($offset)->all();

        return ['items' => $items, 'total' => $total, 'limit' => $limit, 'offset' => $offset];
    }
}
