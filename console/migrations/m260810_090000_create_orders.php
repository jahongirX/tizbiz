<?php

use common\db\Migration;

/**
 * Catalog orders (cafe / restaurant / cakes vertical, Phase 2 seed). An order is
 * a cart of menu items placed from the public site or the Telegram bot. Tenant
 * scoped by business_id; items snapshot name+price so history stays correct even
 * if the menu later changes.
 */
class m260810_090000_create_orders extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%orders}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->integer()->notNull(),
            'client_id' => $this->integer()->null(),
            'customer_name' => $this->string(128)->null(),
            'customer_phone' => $this->string(32)->null(),
            'status' => $this->string(24)->notNull()->defaultValue('new'),
            'total_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),
            'note' => $this->string(500)->null(),
            'source' => $this->string(16)->notNull()->defaultValue('site'),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);
        $this->createIndex('idx-orders-business', '{{%orders}}', 'business_id');
        $this->createIndex('idx-orders-business-status', '{{%orders}}', ['business_id', 'status']);

        $this->createTable('{{%order_items}}', [
            'id' => $this->bigPrimaryKey(),
            'order_id' => $this->integer()->notNull(),
            'business_id' => $this->integer()->notNull(),
            'service_id' => $this->integer()->null(),
            'name' => $this->string(160)->notNull(),
            'price_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),
            'qty' => $this->integer()->notNull()->defaultValue(1),
            'created_at' => $this->integer()->notNull(),
        ], $opts);
        $this->createIndex('idx-order_items-order', '{{%order_items}}', 'order_id');
        $this->createIndex('idx-order_items-business', '{{%order_items}}', 'business_id');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%order_items}}');
        $this->dropTable('{{%orders}}');
    }
}
