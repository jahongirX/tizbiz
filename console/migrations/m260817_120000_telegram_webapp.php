<?php

use common\db\Migration;

/**
 * Telegram Mini App support:
 *   orders.tg_user_id         ties a catalog order to the Telegram user that
 *                             placed it (via verified WebApp initData), so the
 *                             bot can show that user their own order history.
 *   telegram_links.tg_user_id the user id behind a chat (== chat id in private
 *                             chats, but stored explicitly for lookups).
 *   telegram_links.phone      phone the user shared via the bot's request_contact
 *   telegram_links.first_name display name captured alongside the contact.
 */
class m260817_120000_telegram_webapp extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%orders}}', 'tg_user_id', $this->bigInteger()->null());
        $this->createIndex('idx-orders-tg_user', '{{%orders}}', 'tg_user_id');

        $this->addColumn('{{%telegram_links}}', 'tg_user_id', $this->bigInteger()->null());
        $this->addColumn('{{%telegram_links}}', 'phone', $this->string(32)->null());
        $this->addColumn('{{%telegram_links}}', 'first_name', $this->string(128)->null());
        $this->createIndex('idx-telegram_links-tg_user', '{{%telegram_links}}', 'tg_user_id');
    }

    public function safeDown(): void
    {
        $this->dropIndex('idx-telegram_links-tg_user', '{{%telegram_links}}');
        $this->dropColumn('{{%telegram_links}}', 'first_name');
        $this->dropColumn('{{%telegram_links}}', 'phone');
        $this->dropColumn('{{%telegram_links}}', 'tg_user_id');

        $this->dropIndex('idx-orders-tg_user', '{{%orders}}');
        $this->dropColumn('{{%orders}}', 'tg_user_id');
    }
}
