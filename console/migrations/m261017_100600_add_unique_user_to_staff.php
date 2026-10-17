<?php

use common\db\Migration;
use yii\db\Query;

/**
 * A login account (users.id) may be linked to at most one staff row per
 * business: the staff self-service API (/v1/me/*) resolves "me" through that
 * link. Existing duplicates are resolved first (lowest staff.id keeps the link,
 * the others are unlinked), then a UNIQUE (business_id, user_id) index is added.
 * NULL user_id stays allowed any number of times.
 */
class m261017_100600_add_unique_user_to_staff extends Migration
{
    public function safeUp(): void
    {
        // Driver-agnostic data fix (no multi-table UPDATE / window functions).
        $dupes = (new Query())
            ->select(['business_id', 'user_id', 'keep_id' => 'MIN(id)'])
            ->from('{{%staff}}')
            ->where(['not', ['user_id' => null]])
            ->groupBy(['business_id', 'user_id'])
            ->having('COUNT(*) > 1')
            ->all($this->db);

        foreach ($dupes as $row) {
            $this->update(
                '{{%staff}}',
                ['user_id' => null],
                [
                    'and',
                    ['business_id' => (int) $row['business_id'], 'user_id' => (int) $row['user_id']],
                    ['<>', 'id', (int) $row['keep_id']],
                ]
            );
        }

        $this->createIndex('uq-staff-business-user', '{{%staff}}', ['business_id', 'user_id'], true);
    }

    public function safeDown(): void
    {
        $this->dropIndex('uq-staff-business-user', '{{%staff}}');
    }
}
