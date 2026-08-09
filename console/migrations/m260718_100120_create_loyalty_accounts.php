<?php

use common\db\Migration;

/**
 * Per-client loyalty balance within a business. cashback_tiyin in tiyin.
 */
class m260718_100120_create_loyalty_accounts extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%loyalty_accounts}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'client_id' => $this->bigInteger()->notNull(),
            'points' => $this->integer()->notNull()->defaultValue(0),
            'cashback_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('uq-loyalty_accounts', '{{%loyalty_accounts}}', ['business_id', 'client_id'], true);
        $this->addForeignKey('fk-loyalty_accounts-business', '{{%loyalty_accounts}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-loyalty_accounts-client', '{{%loyalty_accounts}}', 'client_id', '{{%clients}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%loyalty_accounts}}');
    }
}
