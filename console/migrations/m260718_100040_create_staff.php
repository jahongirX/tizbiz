<?php

use common\db\Migration;

/**
 * Service providers inside a business (usta/shifokor/registratura). May or may
 * not have a login account (user_id).
 */
class m260718_100040_create_staff extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%staff}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'user_id' => $this->bigInteger()->null(),
            'name' => $this->string(128)->notNull(),
            'specialization' => $this->string(96)->null(),
            'is_active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-staff-business', '{{%staff}}', 'business_id');
        $this->addForeignKey('fk-staff-business', '{{%staff}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-staff-user', '{{%staff}}', 'user_id', '{{%users}}', 'id', 'SET NULL', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%staff}}');
    }
}
