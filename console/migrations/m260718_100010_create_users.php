<?php

use common\db\Migration;

/**
 * Platform accounts. A user can act inside several businesses via business_user.
 */
class m260718_100010_create_users extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%users}}', [
            'id' => $this->bigPrimaryKey(),
            'phone' => $this->string(32)->notNull(),
            'name' => $this->string(128)->notNull(),
            'password_hash' => $this->string(255)->null(),
            'status' => $this->tinyInteger()->notNull()->defaultValue(10),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('uq-users-phone', '{{%users}}', 'phone', true);
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%users}}');
    }
}
