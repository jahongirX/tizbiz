<?php

use common\db\Migration;

/**
 * Directory listings imported from open sources (OpenStreetMap, public web)
 * before the business joins: `is_claimed` = 0 until an owner connects it (no
 * online booking, no storefront mini-site), `source`/`source_ref` identify the
 * record so a re-import updates instead of duplicating.
 */
class m261019_100000_add_listing_source_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $t = '{{%businesses}}';
        $this->addColumn($t, 'is_claimed', $this->boolean()->notNull()->defaultValue(true)->after('is_listed'));
        $this->addColumn($t, 'source', $this->string(16)->null()->after('is_claimed'));
        $this->addColumn($t, 'source_ref', $this->string(64)->null()->after('source'));
        $this->createIndex('ux-businesses-source', $t, ['source', 'source_ref'], true);
    }

    public function safeDown(): void
    {
        $t = '{{%businesses}}';
        $this->dropIndex('ux-businesses-source', $t);
        $this->dropColumn($t, 'source_ref');
        $this->dropColumn($t, 'source');
        $this->dropColumn($t, 'is_claimed');
    }
}
