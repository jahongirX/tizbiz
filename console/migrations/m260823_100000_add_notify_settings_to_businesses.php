<?php

use common\db\Migration;

/**
 * Per-business notification settings. A shop decides whether clients get an SMS
 * (or Telegram message) when they book and before they come, and how early the
 * reminder goes out. Defaults keep the current behaviour: reminders were already
 * sent by cron, and a confirmation is what a client expects after booking.
 */
class m260823_100000_add_notify_settings_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'notify_confirmation', $this->boolean()->notNull()->defaultValue(true));
        $this->addColumn('{{%businesses}}', 'notify_reminder', $this->boolean()->notNull()->defaultValue(true));
        $this->addColumn('{{%businesses}}', 'reminder_hours', $this->integer()->notNull()->defaultValue(24));
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'reminder_hours');
        $this->dropColumn('{{%businesses}}', 'notify_reminder');
        $this->dropColumn('{{%businesses}}', 'notify_confirmation');
    }
}
