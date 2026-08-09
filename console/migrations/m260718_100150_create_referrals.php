<?php

use common\db\Migration;

/**
 * Client-brings-a-friend tracking. bonus_status: pending/granted/void.
 */
class m260718_100150_create_referrals extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%referrals}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'referrer_client_id' => $this->bigInteger()->notNull(),
            'referred_client_id' => $this->bigInteger()->null(),
            'bonus_status' => $this->string(16)->notNull()->defaultValue('pending'),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-referrals-business', '{{%referrals}}', 'business_id');
        $this->createIndex('idx-referrals-referrer', '{{%referrals}}', 'referrer_client_id');
        $this->addForeignKey('fk-referrals-business', '{{%referrals}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-referrals-referrer', '{{%referrals}}', 'referrer_client_id', '{{%clients}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-referrals-referred', '{{%referrals}}', 'referred_client_id', '{{%clients}}', 'id', 'SET NULL', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%referrals}}');
    }
}
