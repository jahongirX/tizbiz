<?php

use common\db\Migration;

/**
 * Optional grouping of services within a business.
 */
class m260718_100050_create_service_categories extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%service_categories}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'name' => $this->string(96)->notNull(),
            'sort' => $this->integer()->notNull()->defaultValue(0),
        ], $opts);

        $this->createIndex('idx-service_categories-business', '{{%service_categories}}', 'business_id');
        $this->addForeignKey('fk-service_categories-business', '{{%service_categories}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%service_categories}}');
    }
}
