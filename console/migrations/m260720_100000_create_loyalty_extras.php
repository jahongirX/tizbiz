<?php

use common\db\Migration;

/**
 * Loyalty add-ons: gift certificates, subscription (pass) types, and client
 * account deposits. Money in tiyin.
 */
class m260720_100000_create_loyalty_extras extends Migration
{
    public function safeUp(): void
    {
        // Gift certificates (Sertifikatlar).
        $this->createTable('{{%certificates}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'code' => $this->string(40)->notNull(),
            'name' => $this->string(120)->notNull()->defaultValue(''),
            'value_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),   // nominal
            'balance_tiyin' => $this->bigInteger()->notNull()->defaultValue(0), // remaining
            'client_id' => $this->bigInteger()->null(),                         // buyer/holder
            'status' => $this->string(12)->notNull()->defaultValue('active'),   // active|used|void
            'expires_at' => $this->date()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());
        $this->createIndex('uq-certificates-code', '{{%certificates}}', ['business_id', 'code'], true);
        $this->addForeignKey('fk-certificates-business', '{{%certificates}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-certificates-client', '{{%certificates}}', 'client_id', '{{%clients}}', 'id', 'SET NULL', 'CASCADE');

        // Subscription / pass types (Abonementlar).
        $this->createTable('{{%subscription_types}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'name' => $this->string(120)->notNull(),
            'visits' => $this->integer()->notNull()->defaultValue(1),      // included visits/uses
            'price_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),
            'valid_days' => $this->integer()->notNull()->defaultValue(30), // validity period
            'is_active' => $this->boolean()->notNull()->defaultValue(true),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $this->tableOptions());
        $this->createIndex('idx-subscription_types-business', '{{%subscription_types}}', 'business_id');
        $this->addForeignKey('fk-subscription_types-business', '{{%subscription_types}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');

        // Client account deposits ledger (Depozitlar). Balance = SUM(delta_tiyin).
        $this->createTable('{{%deposit_transactions}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'client_id' => $this->bigInteger()->notNull(),
            'delta_tiyin' => $this->bigInteger()->notNull(),  // signed: + topup, - spend
            'type' => $this->string(12)->notNull(),           // topup|spend|refund
            'reason' => $this->string(160)->null(),
            'created_at' => $this->integer()->notNull(),
        ], $this->tableOptions());
        $this->createIndex('idx-deposit_transactions-client', '{{%deposit_transactions}}', ['business_id', 'client_id']);
        $this->addForeignKey('fk-deposit_transactions-business', '{{%deposit_transactions}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-deposit_transactions-client', '{{%deposit_transactions}}', 'client_id', '{{%clients}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%deposit_transactions}}');
        $this->dropTable('{{%subscription_types}}');
        $this->dropTable('{{%certificates}}');
    }
}
