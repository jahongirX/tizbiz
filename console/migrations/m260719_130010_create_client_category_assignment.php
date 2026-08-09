<?php

use common\db\Migration;

/**
 * Many-to-many: which categories a client belongs to.
 */
class m260719_130010_create_client_category_assignment extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%client_category_assignment}}', [
            'id' => $this->bigPrimaryKey(),
            'client_id' => $this->bigInteger()->notNull(),
            'category_id' => $this->bigInteger()->notNull(),
            'created_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('uq-client_category', '{{%client_category_assignment}}', ['client_id', 'category_id'], true);
        $this->createIndex('idx-client_category-category', '{{%client_category_assignment}}', 'category_id');
        $this->addForeignKey('fk-client_category-client', '{{%client_category_assignment}}', 'client_id', '{{%clients}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-client_category-category', '{{%client_category_assignment}}', 'category_id', '{{%client_categories}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%client_category_assignment}}');
    }
}
