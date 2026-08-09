<?php

use common\db\Migration;

/**
 * Immutable stock ledger: every change to a product's stock is a movement.
 * type: in (kirim) | out (chiqim) | writeoff (hisobdan chiqarish) | adjust (tuzatish) | sale (sotuv).
 */
class m260719_150010_create_stock_movements extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%stock_movements}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'product_id' => $this->bigInteger()->notNull(),
            'delta_qty' => $this->integer()->notNull(), // signed change
            'type' => $this->string(16)->notNull(),
            'reason' => $this->string(160)->null(),
            'created_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('idx-stock_movements-business', '{{%stock_movements}}', 'business_id');
        $this->createIndex('idx-stock_movements-product', '{{%stock_movements}}', 'product_id');
        $this->addForeignKey('fk-stock_movements-business', '{{%stock_movements}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-stock_movements-product', '{{%stock_movements}}', 'product_id', '{{%products}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%stock_movements}}');
    }
}
