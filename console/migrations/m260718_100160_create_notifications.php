<?php

use common\db\Migration;

/**
 * Outbound message log (reminders, confirmations).
 * channel: tg/sms; status: queued/sent/failed.
 */
class m260718_100160_create_notifications extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%notifications}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'client_id' => $this->bigInteger()->null(),
            'channel' => $this->string(8)->notNull(),
            'template' => $this->string(48)->notNull(),
            'payload' => $this->json()->null(),
            'status' => $this->string(16)->notNull()->defaultValue('queued'),
            'sent_at' => $this->integer()->null(),
            'created_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-notifications-business', '{{%notifications}}', 'business_id');
        $this->createIndex('idx-notifications-client', '{{%notifications}}', 'client_id');
        $this->createIndex('idx-notifications-status', '{{%notifications}}', 'status');
        $this->addForeignKey('fk-notifications-business', '{{%notifications}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-notifications-client', '{{%notifications}}', 'client_id', '{{%clients}}', 'id', 'SET NULL', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%notifications}}');
    }
}
