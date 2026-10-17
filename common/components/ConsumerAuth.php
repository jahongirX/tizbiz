<?php

namespace common\components;

use common\models\ConsumerUser;
use Yii;
use yii\web\User as WebUser;

/**
 * Lazily registers a second, stateless user component (`consumerUser`) whose
 * identity is a {@see ConsumerUser}. Consumer/directory controllers point their
 * HttpBearerAuth at it, so `Yii::$app->user` (business identity) stays empty on
 * those requests and the tenant context stays null — those controllers filter
 * every query explicitly by consumer_id / business_id.
 */
final class ConsumerAuth
{
    public const COMPONENT_ID = 'consumerUser';

    public static function userComponent(): WebUser
    {
        if (!Yii::$app->has(self::COMPONENT_ID)) {
            Yii::$app->set(self::COMPONENT_ID, [
                'class' => WebUser::class,
                'identityClass' => ConsumerUser::class,
                'enableSession' => false,
                'enableAutoLogin' => false,
                'loginUrl' => null,
            ]);
        }
        /** @var WebUser $component */
        $component = Yii::$app->get(self::COMPONENT_ID);
        return $component;
    }

    /** The authenticated consumer for this request, or null (anonymous). */
    public static function current(): ?ConsumerUser
    {
        if (!Yii::$app->has(self::COMPONENT_ID)) {
            return null;
        }
        $identity = self::userComponent()->getIdentity(false);
        return $identity instanceof ConsumerUser ? $identity : null;
    }
}
