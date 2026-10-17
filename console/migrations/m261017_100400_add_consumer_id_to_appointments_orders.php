<?php

use common\db\Migration;

/**
 * Link bookings and catalog orders to the Bizcat consumer who placed them
 * (or who was back-linked by phone). Nullable: web/admin rows have none, and
 * account deletion sets it back to NULL while the business keeps its rows.
 */
class m261017_100400_add_consumer_id_to_appointments_orders extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%appointments}}', 'consumer_id', $this->bigInteger()->null()->after('client_id'));
        $this->createIndex('idx-appointments-consumer', '{{%appointments}}', ['consumer_id', 'starts_at']);
        $this->addForeignKey('fk-appointments-consumer', '{{%appointments}}', 'consumer_id', '{{%consumer_users}}', 'id', 'SET NULL', 'CASCADE');

        $this->addColumn('{{%orders}}', 'consumer_id', $this->bigInteger()->null()->after('client_id'));
        $this->createIndex('idx-orders-consumer', '{{%orders}}', ['consumer_id', 'created_at']);
        $this->addForeignKey('fk-orders-consumer', '{{%orders}}', 'consumer_id', '{{%consumer_users}}', 'id', 'SET NULL', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropForeignKey('fk-orders-consumer', '{{%orders}}');
        $this->dropIndex('idx-orders-consumer', '{{%orders}}');
        $this->dropColumn('{{%orders}}', 'consumer_id');

        $this->dropForeignKey('fk-appointments-consumer', '{{%appointments}}');
        $this->dropIndex('idx-appointments-consumer', '{{%appointments}}');
        $this->dropColumn('{{%appointments}}', 'consumer_id');
    }
}
