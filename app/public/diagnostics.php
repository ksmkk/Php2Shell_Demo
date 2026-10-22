<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

echo json_encode([
    'php_version' => PHP_VERSION,
    'sapi' => PHP_SAPI,
    'pid' => getmypid(),
    'request_time' => date(DATE_ATOM),
    'memory_limit' => ini_get('memory_limit'),
    'post_max_size' => ini_get('post_max_size'),
    'upload_max_filesize' => ini_get('upload_max_filesize'),
    'upload_progress_enabled' => ini_get('session.upload_progress.enabled') === '1',
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";

