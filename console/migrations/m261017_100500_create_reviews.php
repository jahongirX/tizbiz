<?php

use common\db\Migration;

/**
 * Consumer reviews of a completed appointment or a delivered order. One review
 * per appointment / per order (UNIQUE allows many NULLs). The business may reply.
 * businesses.rating_avg / rating_count are recomputed from published rows.
 */
class m261017_100500_create_reviews extends Migration
{
    public function safeUp(): void
    {
        $t = '{{%reviews}}';
        $this->createTable($t, [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'consumer_id' => $this->bigInteger()->null(),
            'appointment_id' => $this->bigInteger()->null(),
            'order_id' => $this->bigInteger()->null(),
            'staff_id' => $this->bigInteger()->null(),
            'service_id' => $this->bigInteger()->null(),
            'author_name' => $this->string(64)->notNull(),
            'rating' => $this->smallInteger()->notNull(),
            'comment' => $this->text()->null(),
            'status' => $this->string(16)->notNull()->defaultValue('published'),
            'reply' => $this->text()->null(),
            'replied_at' => $this->integer()->null(),
            'replied_by' => $this->bigInteger()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('uq-reviews-appointment', $t, ['appointment_id'], true);
        $this->createIndex('uq-reviews-order', $t, ['order_id'], true);
        $this->createIndex('idx-reviews-business-status-created', $t, ['business_id', 'status', 'created_at']);
        $this->createIndex('idx-reviews-consumer-created', $t, ['consumer_id', 'created_at']);

        $this->addForeignKey('fk-reviews-business', $t, 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-reviews-consumer', $t, 'consumer_id', '{{%consumer_users}}', 'id', 'SET NULL', 'CASCADE');
        $this->addForeignKey('fk-reviews-appointment', $t, 'appointment_id', '{{%appointments}}', 'id', 'SET NULL', 'CASCADE');
        $this->addForeignKey('fk-reviews-order', $t, 'order_id', '{{%orders}}', 'id', 'SET NULL', 'CASCADE');
    }

    public function safeDown(): void
    {
        $t = '{{%reviews}}';
        $this->dropForeignKey('fk-reviews-order', $t);
        $this->dropForeignKey('fk-reviews-appointment', $t);
        $this->dropForeignKey('fk-reviews-consumer', $t);
        $this->dropForeignKey('fk-reviews-business', $t);
        $this->dropTable($t);
    }
}
