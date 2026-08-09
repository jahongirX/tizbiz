<?php
/**
 * Dev router for the PHP built-in server (local testing only):
 *   php -S 127.0.0.1:8899 -t api/web api/web/router.php
 * Serves real static files, routes everything else through the front controller.
 */
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path !== '/' && is_file(__DIR__ . $path)) {
    return false; // let the built-in server serve the asset
}
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['SCRIPT_FILENAME'] = __DIR__ . '/index.php';
require __DIR__ . '/index.php';
