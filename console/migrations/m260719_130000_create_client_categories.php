<?php

use common\db\Migration;

/**
 * Client categories (labels like VIP / Loyal / Doimiy), managed per business.
 */
class m260719_130000_create_client_categories extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%client_categories}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'name' => $this->string(64)->notNull(),
            'color' => $this->string(16)->notNull()->defaultValue('#6b7280'),
            'sort' => $this->integer()->notNull()->defaultValue(0),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('idx-client_categories-business', '{{%client_categories}}', 'business_id');
        $this->addForeignKey('fk-client_categories-business', '{{%client_categories}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%client_categories}}');
    }
}
