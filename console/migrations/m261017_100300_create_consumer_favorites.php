<?php

use common\db\Migration;

/**
 * Consumer "saved" businesses (heart button in Bizcat).
 */
class m261017_100300_create_consumer_favorites extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%consumer_favorites}}', [
            'id' => $this->bigPrimaryKey(),
            'consumer_id' => $this->bigInteger()->notNull(),
            'business_id' => $this->bigInteger()->notNull(),
            'created_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('uq-consumer_favorites-consumer-business', '{{%consumer_favorites}}', ['consumer_id', 'business_id'], true);
        $this->createIndex('idx-consumer_favorites-business', '{{%consumer_favorites}}', ['business_id']);
        $this->addForeignKey('fk-consumer_favorites-consumer', '{{%consumer_favorites}}', 'consumer_id', '{{%consumer_users}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-consumer_favorites-business', '{{%consumer_favorites}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropForeignKey('fk-consumer_favorites-business', '{{%consumer_favorites}}');
        $this->dropForeignKey('fk-consumer_favorites-consumer', '{{%consumer_favorites}}');
        $this->dropTable('{{%consumer_favorites}}');
    }
}
