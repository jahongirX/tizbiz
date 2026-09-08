<?php

use common\db\Migration;

/**
 * Devices that announced themselves from the phone (the TizBiz SMS app POSTs its
 * gateway-issued credentials here after registering). The dashboard lists the
 * unclaimed ones so an operator can attach a phone by selecting it — no manual
 * typing of login/password. Re-announcing a claimed device refreshes the linked
 * sms_devices credentials (so a phone re-registration auto-syncs its password).
 */
class m260908_160000_create_sms_pending_devices extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%sms_pending_devices}}', [
            'id' => $this->primaryKey(),
            'device_id' => $this->string(190)->notNull(),
            'name' => $this->string(120)->null(),
            'login' => $this->string(190)->null(),
            'password' => $this->string(255)->null(),
            'server' => $this->string(255)->null(),
            'sim_number' => $this->string(32)->null(),
            'status' => $this->string(16)->notNull()->defaultValue('available'),
            'claimed_by' => $this->integer()->null(),
            'sms_device_id' => $this->integer()->null(),
            'announced_at' => $this->integer()->notNull(),
            'claimed_at' => $this->integer()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_pending_devices-device_id', '{{%sms_pending_devices}}', 'device_id', true);
        $this->createIndex('idx-sms_pending_devices-status', '{{%sms_pending_devices}}', 'status');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%sms_pending_devices}}');
    }
}
