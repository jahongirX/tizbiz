<?php

use common\db\Migration;

/**
 * Membership of a user in a business, carrying the per-tenant role.
 */
class m260718_100030_create_business_user extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%business_user}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'user_id' => $this->bigInteger()->notNull(),
            'role' => $this->string(32)->notNull(), // business_owner/business_admin/staff
            'created_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('uq-business_user', '{{%business_user}}', ['business_id', 'user_id'], true);
        $this->createIndex('idx-business_user-user', '{{%business_user}}', 'user_id');
        $this->addForeignKey('fk-business_user-business', '{{%business_user}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-business_user-user', '{{%business_user}}', 'user_id', '{{%users}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%business_user}}');
    }
}
