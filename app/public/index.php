<?php
declare(strict_types=1);

// Crea una sesión ordinaria para que el navegador envíe su cookie en la
// solicitud multipart. El procesamiento de upload_progress ocurre antes
// de ejecutar upload.php.
session_start();
session_write_close();

$version = PHP_VERSION;
$sapi = PHP_SAPI;
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Laboratorio PHP2SHELL · Academia de Ciberseguridad UCN</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="masthead">
    <div class="wrap">
        <p class="eyebrow">Academia de Ciberseguridad UCN · Laboratorio docente</p>
        <h1>PHP2SHELL</h1>
        <p>Observa el ciclo de vida de las solicitudes y compara dos versiones reales de PHP.</p>
    </div>
</header>
<main class="wrap">
    <section class="panel">
        <h2>Esta instancia</h2>
        <dl class="facts">
            <div><dt>Versión de PHP</dt><dd><?= htmlspecialchars($version, ENT_QUOTES, 'UTF-8') ?></dd></div>
            <div><dt>Interfaz de servidor</dt><dd><?= htmlspecialchars($sapi, ENT_QUOTES, 'UTF-8') ?></dd></div>
            <div><dt>Salud</dt><dd><a href="/health.php">Comprobar respuesta</a></dd></div>
        </dl>
        <p class="note">La versión y el SAPI se obtienen del proceso actual. Para verificar el contenedor y sus límites, usa <code>./scripts/verify.sh</code> en Kali.</p>
    </section>

    <div class="grid">
        <section class="panel">
            <h2>Solicitud multipart</h2>
            <p>Sube un archivo de prueba. La aplicación lee sus metadatos y calcula un resumen SHA-256; no lo guarda en el directorio web.</p>
            <form action="/upload.php" method="post" enctype="multipart/form-data">
                <input type="hidden" name="PHP_SESSION_UPLOAD_PROGRESS" value="ucn-lab">
                <label for="sample">Archivo de prueba</label>
                <input id="sample" name="sample" type="file" required>
                <button type="submit">Procesar archivo</button>
            </form>
        </section>
        <section class="panel">
            <h2>Explorar</h2>
            <ul>
                <li><a href="/diagnostics.php">Diagnóstico JSON</a>: versión, SAPI y proceso.</li>
                <li><a href="/observations.php">Hoja de observaciones</a>: registra resultados de ambas versiones.</li>
            </ul>
            <p class="note">Una respuesta HTTP, un error de memoria o una caída no demuestran por sí solos ejecución de código.</p>
        </section>
    </div>
</main>
<footer class="wrap"><p>Uso exclusivo en la VM local del laboratorio autorizado.</p></footer>
</body>
</html>

