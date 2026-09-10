<?php

use common\db\Migration;

/**
 * Two-step device pairing: an operator requests a phone by number, then the
 * phone itself must confirm from the app before it is bound. These columns hold
 * the in-flight request (who asked, when) until the phone approves/rejects.
 */
class m260910_130000_add_claim_request_to_pending_devices extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%sms_pending_devices}}', 'claim_requested_by', $this->integer()->null());
        $this->addColumn('{{%sms_pending_devices}}', 'claim_requested_at', $this->integer()->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%sms_pending_devices}}', 'claim_requested_at');
        $this->dropColumn('{{%sms_pending_devices}}', 'claim_requested_by');
    }
}
