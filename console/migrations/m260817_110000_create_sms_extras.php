<?php

use common\db\Migration;

/**
 * SMS dashboard extras (sms.tizbiz.uz) — all multi-account, scoped by user_id.
 *   sms_templates  reusable message texts
 *   sms_contacts   saved recipients (name + phone)
 *   sms_blacklist  numbers that must never receive messages
 */
class m260817_110000_create_sms_extras extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%sms_templates}}', [
            'id' => $this->primaryKey(),
            'user_id' => $this->integer()->notNull(),
            'name' => $this->string(120)->notNull(),
            'text' => $this->text()->notNull(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_templates-user', '{{%sms_templates}}', 'user_id');

        $this->createTable('{{%sms_contacts}}', [
            'id' => $this->primaryKey(),
            'user_id' => $this->integer()->notNull(),
            'name' => $this->string(120)->notNull(),
            'phone' => $this->string(32)->notNull(),
            'note' => $this->string(255)->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_contacts-user', '{{%sms_contacts}}', 'user_id');
        // One phone per account.
        $this->createIndex('idx-sms_contacts-user-phone', '{{%sms_contacts}}', ['user_id', 'phone'], true);

        $this->createTable('{{%sms_blacklist}}', [
            'id' => $this->primaryKey(),
            'user_id' => $this->integer()->notNull(),
            'phone' => $this->string(32)->notNull(),
            'reason' => $this->string(255)->null(),
            'created_at' => $this->integer()->notNull(),
        ]);
        // A number is blacklisted at most once per account.
        $this->createIndex('idx-sms_blacklist-user-phone', '{{%sms_blacklist}}', ['user_id', 'phone'], true);
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%sms_blacklist}}');
        $this->dropTable('{{%sms_contacts}}');
        $this->dropTable('{{%sms_templates}}');
    }
}
