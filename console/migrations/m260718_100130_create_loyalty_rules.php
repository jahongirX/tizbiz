<?php

use common\db\Migration;

/**
 * Loyalty configuration per business.
 * earn_rate: cashback earned in basis points of the paid amount
 *            (cashback_tiyin = amount_tiyin * earn_rate / 10000).
 * gift_config: JSON describing gifts/promotions (thresholds, birthday bonus…).
 */
class m260718_100130_create_loyalty_rules extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%loyalty_rules}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'earn_rate' => $this->integer()->notNull()->defaultValue(0),
            'gift_config' => $this->json()->null(),
            'active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-loyalty_rules-business', '{{%loyalty_rules}}', 'business_id');
        $this->addForeignKey('fk-loyalty_rules-business', '{{%loyalty_rules}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%loyalty_rules}}');
    }
}
