<?php
/**
 * Common bootstrap — path aliases shared by every application tier.
 * Repo root is the Yii2 advanced root; each tier is a top-level directory.
 */
$root = dirname(dirname(__DIR__)); // …/common/config -> repo root
Yii::setAlias('@root', $root);
Yii::setAlias('@common', $root . '/common');
Yii::setAlias('@api', $root . '/api');
Yii::setAlias('@frontend', $root . '/frontend');
Yii::setAlias('@backend', $root . '/backend');
Yii::setAlias('@tenant', $root . '/tenant');
Yii::setAlias('@console', $root . '/console');
