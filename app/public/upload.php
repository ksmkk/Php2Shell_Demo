<?php
declare(strict_types=1);

function escape_html(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

$ok = false;
$message = '';
$size = null;
$digest = null;

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    $message = 'Este recurso acepta únicamente solicitudes POST.';
} elseif (!isset($_FILES['sample']) || !is_array($_FILES['sample'])) {
    http_response_code(400);
    $message = 'No se recibió un archivo. Comprueba el tamaño máximo permitido.';
} elseif (is_array($_FILES['sample']['error'] ?? null) || ($_FILES['sample']['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
    http_response_code(400);
    $message = 'PHP informó un error de carga: ' . (string) ($_FILES['sample']['error'] ?? UPLOAD_ERR_NO_FILE);
} else {
    $tmp = $_FILES['sample']['tmp_name'] ?? '';
    if (!is_string($tmp) || !is_uploaded_file($tmp)) {
        http_response_code(400);
        $message = 'El archivo temporal no pasó la verificación de carga.';
    } else {
        $result = hash_file('sha256', $tmp);
        if ($result === false) {
            http_response_code(500);
            $message = 'No se pudo calcular el resumen del archivo temporal.';
        } else {
            $ok = true;
            $message = 'PHP procesó la carga.';
            $size = filesize($tmp);
            $digest = $result;
        }
    }
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Resultado de carga · PHP2SHELL</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="masthead compact"><div class="wrap"><p class="eyebrow">Academia de Ciberseguridad UCN</p><h1>Resultado multipart</h1></div></header>
<main class="wrap">
    <section class="panel">
        <h2><?= escape_html($message) ?></h2>
        <dl class="facts">
            <div><dt>Versión de PHP</dt><dd><?= escape_html(PHP_VERSION) ?></dd></div>
            <div><dt>Resultado</dt><dd><?= $ok ? 'Carga procesada' : 'Carga no procesada' ?></dd></div>
            <?php if ($ok): ?>
            <div><dt>Tamaño leído</dt><dd><?= escape_html((string) $size) ?> bytes</dd></div>
            <div><dt>SHA-256</dt><dd><code><?= escape_html((string) $digest) ?></code></dd></div>
            <?php endif; ?>
        </dl>
        <p class="note">El archivo temporal se elimina al terminar la solicitud. No se acepta una ruta de destino ni se ejecuta su contenido.</p>
        <p><a href="/">Volver al laboratorio</a></p>
    </section>
</main>
</body>
</html>

