<?php

use common\db\Migration;

/**
 * Telegram bot connection per business. The owner pastes a bot token (from
 * @BotFather) in settings; once a public webhook is wired the bot serves the
 * same catalog + order history. Nullable/additive — no bot until a token is set.
 */
class m260810_091000_add_telegram_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'telegram_bot_token', $this->string(80)->null());
        $this->addColumn('{{%businesses}}', 'telegram_bot_username', $this->string(64)->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'telegram_bot_username');
        $this->dropColumn('{{%businesses}}', 'telegram_bot_token');
    }
}
