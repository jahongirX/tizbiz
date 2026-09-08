<?php

namespace api\modules\superadmin\controllers;

use common\models\SmsRecipient;
use Yii;

/**
 * Central base of every phone number the platform's accounts have sent to.
 */
class RecipientController extends BaseController
{
    public function actionIndex(): array
    {
        $q = SmsRecipient::find();
        if (($term = trim((string) Yii::$app->request->get('q'))) !== '') {
            $digits = preg_replace('/\D+/', '', $term);
            if ($digits !== '') {
                $q->andWhere(['like', 'phone', $digits]);
            }
        }
        $sort = Yii::$app->request->get('sort') === 'count' ? 'send_count' : 'last_seen_at';
        return [
            'total' => (int) SmsRecipient::find()->count(),
            'items' => $q->orderBy([$sort => SORT_DESC])->limit(2000)->all(),
        ];
    }
}
