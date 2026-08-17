<?php

use common\db\Migration;

/**
 * SMS gateway dashboard (sms.tizbiz.uz) — multi-account, scoped by user_id.
 *   sms_devices   registered Android phones (servers) with gateway credentials
 *   sms_messages  outbound message log with delivery status
 */
class m260817_100000_create_sms extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%sms_devices}}', [
            'id' => $this->primaryKey(),
            'user_id' => $this->integer()->notNull(),
            'name' => $this->string(120)->notNull(),
            'server' => $this->string(255)->null(),      // base URL; null => cloud default
            'login' => $this->string(190)->null(),
            'password' => $this->string(255)->null(),
            'external_id' => $this->string(190)->null(),
            'status' => $this->string(16)->notNull()->defaultValue('offline'),
            'is_active' => $this->boolean()->notNull()->defaultValue(true),
            'last_seen_at' => $this->integer()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_devices-user', '{{%sms_devices}}', 'user_id');

        $this->createTable('{{%sms_messages}}', [
            'id' => $this->primaryKey(),
            'user_id' => $this->integer()->notNull(),
            'device_id' => $this->integer()->null(),
            'phone' => $this->string(32)->notNull(),
            'text' => $this->text()->notNull(),
            'status' => $this->string(16)->notNull()->defaultValue('pending'), // pending/sent/failed
            'external_id' => $this->string(190)->null(),
            'error' => $this->string(500)->null(),
            'sent_at' => $this->integer()->null(),
            'created_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_messages-user', '{{%sms_messages}}', 'user_id');
        $this->createIndex('idx-sms_messages-status', '{{%sms_messages}}', 'status');
        $this->createIndex('idx-sms_messages-device', '{{%sms_messages}}', 'device_id');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%sms_messages}}');
        $this->dropTable('{{%sms_devices}}');
    }
}
