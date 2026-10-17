<?php

use common\db\Migration;

/**
 * Bizcat consumer accounts (phone + OTP login). Separate from `users` (business
 * staff/owners): a person can be both without the two ever colliding.
 * On account deletion the row is anonymized (phone => "deleted-<id>").
 */
class m261017_100100_create_consumer_users extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%consumer_users}}', [
            'id' => $this->bigPrimaryKey(),
            'phone' => $this->string(32)->notNull(),
            'name' => $this->string(128)->null(),
            'birthday' => $this->date()->null(),
            'gender' => $this->string(8)->null(),
            'city' => $this->string(64)->null(),
            'locale' => $this->string(5)->notNull()->defaultValue('uz'),
            'status' => $this->smallInteger()->notNull()->defaultValue(10),
            'last_login_at' => $this->integer()->null(),
            'deleted_at' => $this->integer()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('uq-consumer_users-phone', '{{%consumer_users}}', ['phone'], true);
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%consumer_users}}');
    }
}
