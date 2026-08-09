<?php

namespace common\db;

use yii\db\Migration as BaseMigration;

/**
 * Project migration base. Foreign keys target MySQL (production); on SQLite
 * (used for local/CI functional testing) ALTER TABLE ADD CONSTRAINT is not
 * supported, so FK operations are skipped there. Table data/columns are
 * identical across both drivers.
 */
class Migration extends BaseMigration
{
    /** MySQL table options (utf8mb4 InnoDB); null on other drivers. */
    public function tableOptions(): ?string
    {
        return $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB'
            : null;
    }

    public function addForeignKey($name, $table, $columns, $refTable, $refColumns, $delete = null, $update = null): void
    {
        if ($this->db->driverName === 'sqlite') {
            return;
        }
        parent::addForeignKey($name, $table, $columns, $refTable, $refColumns, $delete, $update);
    }

    public function dropForeignKey($name, $table): void
    {
        if ($this->db->driverName === 'sqlite') {
            return;
        }
        parent::dropForeignKey($name, $table);
    }
}
