<?php

namespace api\modules\loyalty\controllers;

use common\models\LoyaltyRule;
use common\rest\Controller;
use Yii;

/**
 * Loyalty settings: a flat view over the active {@see LoyaltyRule} row.
 *
 * `earn_rate` is a real column; the remaining settings live inside the row's
 * `gift_config` JSON. Reads are open to any authed tenant user; writes require
 * owner/admin. If no active rule exists yet, one is created on first read/write.
 */
class SettingsController extends Controller
{
    /** Settings that are persisted inside the gift_config JSON blob. */
    private const GIFT_KEYS = [
        'referral_bonus_tiyin',
        'referral_bonus_points',
        'discount_cancel_days',
        'sms_notify_days',
    ];

    /** GET /v1/loyalty/settings */
    public function actionView(): array
    {
        return $this->present($this->activeRule());
    }

    /** PUT /v1/loyalty/settings */
    public function actionUpdate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $rule = $this->activeRule();
        $body = $this->body();

        if (array_key_exists('earn_rate', $body)) {
            $rule->earn_rate = (int) $body['earn_rate'];
        }

        $config = is_array($rule->gift_config) ? $rule->gift_config : [];
        foreach (self::GIFT_KEYS as $key) {
            if (array_key_exists($key, $body)) {
                $config[$key] = (int) $body[$key];
            }
        }
        $rule->gift_config = $config;

        if (!$rule->save()) {
            return $this->fail422($rule);
        }

        return $this->present($rule);
    }

    /**
     * The active loyalty rule for the business, creating one if none exists so
     * settings always have a home.
     */
    private function activeRule(): LoyaltyRule
    {
        $businessId = Yii::$app->tenant->require();

        $rule = LoyaltyRule::find()
            ->where(['business_id' => $businessId, 'active' => true])
            ->orderBy(['id' => SORT_DESC])
            ->one();

        if ($rule === null) {
            $rule = new LoyaltyRule();
            $rule->business_id = $businessId;
            $rule->active = true;
            $rule->earn_rate = 0;
            $rule->gift_config = [];
            $rule->save();
        }

        return $rule;
    }

    /** Flatten the rule (earn_rate column + gift_config keys) into the settings shape. */
    private function present(LoyaltyRule $rule): array
    {
        $config = is_array($rule->gift_config) ? $rule->gift_config : [];

        return [
            'earn_rate' => (int) $rule->earn_rate,
            'referral_bonus_tiyin' => (int) ($config['referral_bonus_tiyin'] ?? 0),
            'referral_bonus_points' => (int) ($config['referral_bonus_points'] ?? 0),
            'discount_cancel_days' => (int) ($config['discount_cancel_days'] ?? 0),
            'sms_notify_days' => (int) ($config['sms_notify_days'] ?? 0),
        ];
    }
}
