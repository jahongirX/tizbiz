<?php

use common\db\Migration;

/**
 * Auto-assignment of clients to a category based on thresholds (like YClients
 * "Правила для категорий"):
 *   metric = sold|paid|visits|inactive_days ; when threshold is met -> action
 *   (add|remove) the client to/from the category.
 */
class m260719_130030_create_auto_category_rules extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%auto_category_rules}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'category_id' => $this->bigInteger()->notNull(),
            'metric' => $this->string(16)->notNull(), // sold | paid | visits | inactive_days
            'threshold' => $this->bigInteger()->notNull()->defaultValue(0),
            'action' => $this->string(8)->notNull()->defaultValue('add'), // add | remove
            'active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('idx-auto_category_rules-business', '{{%auto_category_rules}}', 'business_id');
        $this->addForeignKey('fk-auto_category_rules-business', '{{%auto_category_rules}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-auto_category_rules-category', '{{%auto_category_rules}}', 'category_id', '{{%client_categories}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%auto_category_rules}}');
    }
}
