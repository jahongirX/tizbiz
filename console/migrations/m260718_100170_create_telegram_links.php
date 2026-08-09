<?php

use common\db\Migration;

/**
 * Binds a Telegram chat to a client and/or platform user, so reminders and the
 * bot can reach the right person. verified_at set once ownership is confirmed.
 */
class m260718_100170_create_telegram_links extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%telegram_links}}', [
            'id' => $this->bigPrimaryKey(),
            'client_id' => $this->bigInteger()->null(),
            'user_id' => $this->bigInteger()->null(),
            'tg_chat_id' => $this->bigInteger()->notNull(),
            'verified_at' => $this->integer()->null(),
            'created_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-telegram_links-chat', '{{%telegram_links}}', 'tg_chat_id');
        $this->createIndex('idx-telegram_links-client', '{{%telegram_links}}', 'client_id');
        $this->createIndex('idx-telegram_links-user', '{{%telegram_links}}', 'user_id');
        $this->addForeignKey('fk-telegram_links-client', '{{%telegram_links}}', 'client_id', '{{%clients}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-telegram_links-user', '{{%telegram_links}}', 'user_id', '{{%users}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%telegram_links}}');
    }
}
