<?php

use common\db\Migration;

/**
 * Branches (filiallar) of a business: each has its own address and map point,
 * so the Bizcat map shows a placemark per branch and the business page lists them.
 */
class m261019_100100_create_business_branches extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%business_branches}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'name' => $this->string(128)->notNull(),
            'city' => $this->string(64)->null(),
            'district' => $this->string(64)->null(),
            'address' => $this->string(255)->null(),
            'landmark' => $this->string(255)->null(),
            'phone' => $this->string(32)->null(),
            'hours' => $this->string(64)->null(),
            'lat' => $this->decimal(10, 7)->null(),
            'lng' => $this->decimal(10, 7)->null(),
            'sort' => $this->integer()->notNull()->defaultValue(0),
            'is_active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());
        $this->createIndex('idx-business_branches-business', '{{%business_branches}}', ['business_id', 'is_active', 'sort']);
        $this->createIndex('idx-business_branches-geo', '{{%business_branches}}', ['lat', 'lng']);
        $this->addForeignKey(
            'fk-business_branches-business',
            '{{%business_branches}}',
            'business_id',
            '{{%businesses}}',
            'id',
            'CASCADE',
            'CASCADE'
        );
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%business_branches}}');
    }
}
