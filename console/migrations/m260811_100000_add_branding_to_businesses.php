<?php

use common\db\Migration;

/**
 * Per-business branding for the public storefront: a logo, a cover/background
 * image, and primary/secondary brand colors (hex). All nullable/additive — a
 * business without them falls back to initials + the per-engine default theme.
 */
class m260811_100000_add_branding_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'logo', $this->string(500)->null());
        $this->addColumn('{{%businesses}}', 'cover', $this->string(500)->null());
        $this->addColumn('{{%businesses}}', 'brand_color', $this->string(9)->null());
        $this->addColumn('{{%businesses}}', 'brand_color_2', $this->string(9)->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'brand_color_2');
        $this->dropColumn('{{%businesses}}', 'brand_color');
        $this->dropColumn('{{%businesses}}', 'cover');
        $this->dropColumn('{{%businesses}}', 'logo');
    }
}
