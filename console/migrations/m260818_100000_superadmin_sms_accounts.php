<?php

use common\db\Migration;

/**
 * Platform superadmin + SMS client accounts.
 *   users.is_superadmin  marks platform operators who manage the SMS service.
 *   sms_accounts         one row per SMS client: their monthly quota + status.
 *                        A user with an active sms_account can use the SMS
 *                        dashboard (sms.tizbiz.uz); the superadmin creates them.
 */
class m260818_100000_superadmin_sms_accounts extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%users}}', 'is_superadmin', $this->boolean()->notNull()->defaultValue(false));

        $this->createTable('{{%sms_accounts}}', [
            'id' => $this->primaryKey(),
            'user_id' => $this->integer()->notNull(),
            'quota_monthly' => $this->integer()->notNull()->defaultValue(0), // 0 = unlimited
            'is_active' => $this->boolean()->notNull()->defaultValue(true),
            'note' => $this->string(255)->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);
        // One SMS account per user.
        $this->createIndex('idx-sms_accounts-user', '{{%sms_accounts}}', 'user_id', true);
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%sms_accounts}}');
        $this->dropColumn('{{%users}}', 'is_superadmin');
    }
}
