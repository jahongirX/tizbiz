<?php

namespace api\modules\consumer\controllers;

use api\modules\consumer\components\ConsumerController;
use common\models\Business;
use Yii;
use yii\db\Expression;
use yii\db\Query;

/**
 * Loyalty wallet across businesses: every active business where a CRM client
 * with the consumer's phone exists, with its points, cashback, deposit balance
 * and completed visits.
 *
 * GET /v1/consumer/loyalty
 */
class LoyaltyController extends ConsumerController
{
    public function actionIndex(): array
    {
        $consumer = $this->consumer();

        $deposit = (new Query())
            ->select(new Expression('COALESCE(SUM(dt.delta_tiyin), 0)'))
            ->from(['dt' => '{{%deposit_transactions}}'])
            ->where('dt.client_id = c.id AND dt.business_id = c.business_id');
        $visits = (new Query())
            ->select(new Expression('COUNT(*)'))
            ->from(['a' => '{{%appointments}}'])
            ->where('a.client_id = c.id AND a.business_id = c.business_id')
            ->andWhere(['a.status' => 'completed']);

        $rows = (new Query())
            ->select([
                'client_id' => 'c.id',
                'business_id' => 'b.id',
                'b.slug',
                'b.name',
                'b.logo',
                'b.brand_color',
                'points' => new Expression('COALESCE(la.points, 0)'),
                'cashback_tiyin' => new Expression('COALESCE(la.cashback_tiyin, 0)'),
                'deposit_balance_tiyin' => $deposit,
                'visits' => $visits,
            ])
            ->from(['c' => '{{%clients}}'])
            ->innerJoin(['b' => Business::tableName()], 'b.id = c.business_id')
            ->leftJoin(['la' => '{{%loyalty_accounts}}'], 'la.client_id = c.id AND la.business_id = c.business_id')
            ->where(['c.phone' => (string) $consumer->phone, 'b.status' => Business::STATUS_ACTIVE])
            ->all(Yii::$app->db);

        $out = [];
        foreach ($rows as $r) {
            $out[] = [
                'business' => [
                    'id' => (int) $r['business_id'],
                    'slug' => $r['slug'],
                    'name' => $r['name'],
                    'logo' => $r['logo'],
                    'brand_color' => $r['brand_color'],
                ],
                'client_id' => (int) $r['client_id'],
                'points' => (int) $r['points'],
                'cashback_tiyin' => (int) $r['cashback_tiyin'],
                'deposit_balance_tiyin' => (int) $r['deposit_balance_tiyin'],
                'visits' => (int) $r['visits'],
            ];
        }
        usort($out, static fn (array $a, array $b) => [$b['cashback_tiyin'], $b['visits']] <=> [$a['cashback_tiyin'], $a['visits']]);
        return $out;
    }
}
