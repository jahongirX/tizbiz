<?php

use common\db\Migration;

/**
 * Editable storefront subtitle (shown under the business name in the public
 * header, e.g. "Onlayn buyurtma"). Nullable — engines fall back to a default.
 */
class m260811_110000_add_tagline_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'tagline', $this->string(160)->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'tagline');
    }
}
