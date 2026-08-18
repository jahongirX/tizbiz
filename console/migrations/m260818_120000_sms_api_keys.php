<?php

use common\db\Migration;
use common\models\SmsAccount;

/**
 * Public API keys for SMS accounts. Each SMS client gets a secret key so their
 * own systems (CRM, e-shop, OTP flows…) can send SMS through the gateway over
 * a simple REST API — no dashboard login required. One key per account; the
 * client can rotate it. Existing accounts are backfilled with a key.
 */
class m260818_120000_sms_api_keys extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%sms_accounts}}', 'api_key', $this->string(64)->null());
        $this->createIndex('idx-sms_accounts-api_key', '{{%sms_accounts}}', 'api_key', true);

        // Backfill a key for every account that predates this column.
        foreach (SmsAccount::find()->where(['api_key' => null])->all() as $acc) {
            $acc->api_key = SmsAccount::generateKey();
            $acc->save(false, ['api_key']);
        }
    }

    public function safeDown(): void
    {
        $this->dropIndex('idx-sms_accounts-api_key', '{{%sms_accounts}}');
        $this->dropColumn('{{%sms_accounts}}', 'api_key');
    }
}
