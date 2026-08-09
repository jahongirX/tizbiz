<?php

use common\db\Migration;

/**
 * Online-booking settings: per-business toggle + lead/horizon window, and a
 * per-service flag for whether it appears on the public booking page.
 */
class m260719_160000_add_booking_settings extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'online_booking_enabled', $this->boolean()->notNull()->defaultValue(true));
        $this->addColumn('{{%businesses}}', 'booking_lead_min', $this->integer()->notNull()->defaultValue(0)); // min minutes before a slot
        $this->addColumn('{{%businesses}}', 'booking_horizon_days', $this->integer()->notNull()->defaultValue(30)); // how far ahead
        $this->addColumn('{{%services}}', 'online_bookable', $this->boolean()->notNull()->defaultValue(true));
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%services}}', 'online_bookable');
        $this->dropColumn('{{%businesses}}', 'booking_horizon_days');
        $this->dropColumn('{{%businesses}}', 'booking_lead_min');
        $this->dropColumn('{{%businesses}}', 'online_booking_enabled');
    }
}
