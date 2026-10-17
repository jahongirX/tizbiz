<?php

use common\db\Migration;

/**
 * One-time login codes for consumers. Only an HMAC of phone|code is stored.
 * Rows double as the rate-limit log (per phone and per IP).
 */
class m261017_100200_create_consumer_otp_codes extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%consumer_otp_codes}}', [
            'id' => $this->bigPrimaryKey(),
            'phone' => $this->string(32)->notNull(),
            'code_hash' => $this->char(64)->notNull(),
            'attempts' => $this->smallInteger()->notNull()->defaultValue(0),
            'expires_at' => $this->integer()->notNull(),
            'consumed_at' => $this->integer()->null(),
            'ip' => $this->string(45)->null(),
            'created_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('idx-consumer_otp_codes-phone-created', '{{%consumer_otp_codes}}', ['phone', 'created_at']);
        $this->createIndex('idx-consumer_otp_codes-ip-created', '{{%consumer_otp_codes}}', ['ip', 'created_at']);
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%consumer_otp_codes}}');
    }
}
