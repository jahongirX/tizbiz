<?php
/**
 * Dev router for the PHP built-in server on the SPA tiers (local only):
 *   php -S 127.0.0.1:8081 -t backend/web common/web/router.php
 * Serves real static files and sends everything else to the tier's front
 * controller, so client-side routes survive a refresh. Production uses the
 * per-tier web/.htaccess instead.
 */
$root = rtrim($_SERVER['DOCUMENT_ROOT'], '/');
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path !== '/' && is_file($root . $path)) {
    return false; // let the built-in server serve the asset
}
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['SCRIPT_FILENAME'] = $root . '/index.php';
require $root . '/index.php';
