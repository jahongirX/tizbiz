<?php

use common\db\Migration;

/**
 * Tenants. Each business is an isolated tenant; `slug` is its subdomain.
 */
class m260718_100020_create_businesses extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%businesses}}', [
            'id' => $this->bigPrimaryKey(),
            'name' => $this->string(160)->notNull(),
            'slug' => $this->string(80)->notNull(),
            'phone' => $this->string(32)->null(),
            'category' => $this->string(48)->null(), // barber/salon/clinic/dentistry/…
            'tariff' => $this->string(24)->notNull()->defaultValue('free'), // free/start/standard/clinic
            'timezone' => $this->string(48)->notNull()->defaultValue('Asia/Tashkent'),
            'status' => $this->tinyInteger()->notNull()->defaultValue(10),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('uq-businesses-slug', '{{%businesses}}', 'slug', true);
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%businesses}}');
    }
}
