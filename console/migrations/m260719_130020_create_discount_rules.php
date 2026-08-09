<?php

use common\db\Migration;

/**
 * Tiered discount rules (like YClients "Правила для скидок"):
 *   metric = sold|paid|visits ; threshold reached -> percent discount.
 *   threshold is in tiyin for sold/paid, and a visit count for visits.
 */
class m260719_130020_create_discount_rules extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%discount_rules}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'metric' => $this->string(16)->notNull(), // sold | paid | visits
            'threshold' => $this->bigInteger()->notNull()->defaultValue(0),
            'percent' => $this->integer()->notNull()->defaultValue(0), // 0..100
            'active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('idx-discount_rules-business', '{{%discount_rules}}', ['business_id', 'metric']);
        $this->addForeignKey('fk-discount_rules-business', '{{%discount_rules}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%discount_rules}}');
    }
}
