<?php

use common\db\Migration;

/**
 * CRM contact, scoped to a business. Unique per (business, phone).
 */
class m260718_100090_create_clients extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%clients}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'name' => $this->string(128)->notNull(),
            'phone' => $this->string(32)->notNull(),
            'birthday' => $this->date()->null(),
            'notes' => $this->text()->null(),
            'tags' => $this->json()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('uq-clients-business-phone', '{{%clients}}', ['business_id', 'phone'], true);
        $this->addForeignKey('fk-clients-business', '{{%clients}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%clients}}');
    }
}
