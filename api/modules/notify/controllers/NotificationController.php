<?php

namespace api\modules\notify\controllers;

use common\models\Client;
use common\models\Notification;
use common\rest\Controller;
use Yii;
use yii\db\Query;

/**
 * What the shop actually sent: the message log behind reminders and booking
 * confirmations. Read-only and tenant-scoped; messages are queued and delivered
 * by the notify services, never created from here.
 */
class NotificationController extends Controller
{
    private const PAGE_SIZE = 30;

    /**
     * GET /v1/notifications?channel=&status=&page=&per_page=
     */
    public function actionIndex(): array
    {
        $businessId = Yii::$app->tenant->require();

        $channel = trim((string) Yii::$app->request->get('channel', ''));
        $status = trim((string) Yii::$app->request->get('status', ''));
        $page = max(1, (int) Yii::$app->request->get('page', 1));
        $perPage = min(100, max(1, (int) Yii::$app->request->get('per_page', self::PAGE_SIZE)));

        $base = (new Query())
            ->from(['n' => Notification::tableName()])
            ->leftJoin(['c' => Client::tableName()], 'c.id = n.client_id')
            ->where(['n.business_id' => $businessId]);

        if ($channel !== '') {
            $base->andWhere(['n.channel' => $channel]);
        }
        if ($status !== '') {
            $base->andWhere(['n.status' => $status]);
        }

        $total = (int) (clone $base)->count('n.id');

        $rows = (clone $base)
            ->select([
                'id' => 'n.id',
                'channel' => 'n.channel',
                'template' => 'n.template',
                'status' => 'n.status',
                'sent_at' => 'n.sent_at',
                'created_at' => 'n.created_at',
                'client_name' => 'c.name',
                'client_phone' => 'c.phone',
            ])
            ->orderBy(['n.created_at' => SORT_DESC, 'n.id' => SORT_DESC])
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->all();

        return [
            'data' => array_map(static fn ($r) => [
                'id' => (int) $r['id'],
                'channel' => $r['channel'],
                'template' => $r['template'],
                'status' => $r['status'],
                'sent_at' => $r['sent_at'] !== null ? (int) $r['sent_at'] : null,
                'created_at' => (int) $r['created_at'],
                'client_name' => $r['client_name'],
                'client_phone' => $r['client_phone'],
            ], $rows),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'pages' => (int) ceil($total / $perPage),
            ],
        ];
    }
}
