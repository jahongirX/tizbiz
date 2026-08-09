<?php

use common\db\Migration;

/**
 * Inventory products (Ombor/Sklad). Money in tiyin; stock is an integer quantity.
 */
class m260719_150000_create_products extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%products}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'name' => $this->string(160)->notNull(),
            'unit' => $this->string(24)->notNull()->defaultValue('dona'),
            'price_tiyin' => $this->bigInteger()->notNull()->defaultValue(0), // sale price
            'cost_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),  // purchase cost
            'stock_qty' => $this->integer()->notNull()->defaultValue(0),
            'low_stock' => $this->integer()->notNull()->defaultValue(0),      // low-stock threshold
            'is_active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('idx-products-business', '{{%products}}', 'business_id');
        $this->addForeignKey('fk-products-business', '{{%products}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%products}}');
    }
}
