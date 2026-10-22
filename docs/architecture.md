# Arquitectura local

## Decisión

Cada alumno usa una VM Kali Linux con Docker Engine. El proyecto Compose crea dos PHP independientes y dos pasarelas TCP. No hay servidor central ni direcciones de laboratorio asignadas por alumno.

```text
Navegador y herramientas en Kali
       ├── 127.0.0.1:8081 → gateway-vulnerable → PHP 8.4.26
       └── 127.0.0.1:8082 → gateway-patched    → PHP 8.4.27
                                redes internas separadas
```

Cada contenedor PHP tiene sus propios procesos Apache, almacenamiento temporal, sesiones y capa escribible. El código web y la configuración proceden de los mismos archivos durante la construcción. `reset vulnerable` recrea únicamente el contenedor vulnerable; los registros anteriores se guardan primero en `evidence/`.

## Por qué existen las pasarelas

Las redes Docker `internal` impiden a los contenedores PHP tener una ruta externa. La publicación directa de puertos en una red exclusivamente interna ha mostrado diferencias de comportamiento entre versiones de Docker. Cada pasarela se conecta a una sola red PHP y a una red frontal normal. Publica **solo** en `127.0.0.1` de Kali y trabaja en modo TCP, de modo que no modifica encabezados ni el cuerpo HTTP. Las pasarelas son una imagen adicional que se exporta junto a las dos imágenes PHP.

Esta topología reduce la salida y el movimiento entre versiones, pero no equivale a una barrera absoluta: un fallo del runtime, del kernel, de la pasarela o una configuración de red inesperada puede cambiar el aislamiento. La Fase 4 debe verificarlo desde dentro de cada contenedor y desde otra máquina de la LAN. Las pruebas de corrupción de memoria se ejecutarán solamente en la VM autorizada.

## Comparabilidad

| Aspecto | Vulnerable | Corregido |
|---|---|---|
| Imagen base | `php:8.4.26-apache` | `php:8.4.27-apache` |
| Aplicación | `app/public/` | `app/public/` |
| PHP y Apache | Archivos de `config/` | Los mismos archivos |
| Memoria y CPU iniciales | 512 MiB, 1 CPU | 512 MiB, 1 CPU |
| Puerto local predeterminado | 8081 | 8082 |

Las etiquetas de imagen deben complementarse con los digests registrados durante la preparación offline. Si una prueba falla, el informe incluirá versión, SAPI, configuración, solicitud, respuesta, estado del proceso y registros. Un código HTTP o una caída aislada no identifican por sí mismos la causa raíz.

## Superficie de la aplicación

- `/`: inicia y cierra una sesión ordinaria para entregar la cookie al navegador; muestra la versión real, enlaces y un formulario multipart.
- `/health.php`: respuesta mínima para salud.
- `/diagnostics.php`: versión, SAPI, PID y parámetros relevantes.
- `/upload.php`: procesa un archivo temporal y calcula SHA-256 sin moverlo al directorio web.
- `/observations.php`: tabla imprimible para registrar datos de ambas versiones.

No hay inclusión de rutas proporcionadas por el usuario, ejecución de archivos subidos ni deserialización de datos de la solicitud. El formulario incluye el campo que activa el seguimiento de carga de PHP; las pruebas diagnósticas adicionales se diseñarán y documentarán en la Fase 4.

## Recursos y recuperación

Compose fija límites iniciales de memoria, swap, CPU y procesos. Los registros de Apache y PHP se consultan con `docker compose logs`; `snapshot` conserva estado y registros antes de `reset`. Una instancia PHP detenida debe dejar disponible la otra. Los límites definitivos dependerán de las mediciones en la Kali usada para clase.

