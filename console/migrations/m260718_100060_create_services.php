<?php

use common\db\Migration;

/**
 * Bookable services. Money is stored in tiyin (1/100 so'm).
 */
class m260718_100060_create_services extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%services}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'category_id' => $this->bigInteger()->null(),
            'name' => $this->string(128)->notNull(),
            'duration_min' => $this->integer()->notNull()->defaultValue(30),
            'price_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),
            'deposit_tiyin' => $this->bigInteger()->null(), // null = business does not require a deposit
            'is_active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-services-business', '{{%services}}', 'business_id');
        $this->createIndex('idx-services-category', '{{%services}}', 'category_id');
        $this->addForeignKey('fk-services-business', '{{%services}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-services-category', '{{%services}}', 'category_id', '{{%service_categories}}', 'id', 'SET NULL', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%services}}');
    }
}
