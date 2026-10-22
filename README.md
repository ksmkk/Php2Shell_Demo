# Laboratorio PHP2SHELL · Academia de Ciberseguridad UCN

Mini CTF local para comparar PHP **8.4.26** y **8.4.27** con la misma aplicación, configuración y servidor Apache/mod_php. Cada alumno ejecuta su propia copia dentro de Kali Linux en VirtualBox. El objetivo visible es un portal ficticio de gestión documental; la guía del desafío está en [docs/ctf.md](docs/ctf.md). La primera etapa experimental se limita a reconocimiento, análisis y comparación; no incluye una cadena automatizada de RCE.

## Despliegue rápido

Desde la raíz del proyecto, con Docker Engine y Docker Compose disponibles:

```bash
./deploy.sh
```

Si tu copia perdió el permiso de ejecución al transportarla, usa `bash deploy.sh`.

Después de actualizar una instalación existente con `git pull --ff-only`, ejecuta `./deploy.sh --rebuild` para incorporar la nueva aplicación a las dos imágenes.

En Kali, el script instala `docker.io`, `docker-compose` y `curl` desde los repositorios configurados si faltan. Puede pedir la contraseña de `sudo` y requiere internet para esa instalación. Si Docker ya existe pero el servicio está detenido, intenta iniciarlo. Si la cuenta no puede abrir el socket local de Docker y el motor sí responde con `sudo`, agrega esa cuenta al grupo `docker` y continúa en una sesión con el grupo activo. Esta pertenencia concede acceso administrativo a Docker dentro de la VM; al terminar el script, abre una nueva sesión para que otros comandos también hereden el grupo. Consulta [la resolución de problemas](docs/troubleshooting.md). Después usa las imágenes locales si están presentes; si faltan, importa el paquete de `offline/` cuando está disponible o construye las imágenes oficiales con internet. Crea `.env` con los puertos locales predeterminados, inicia los cuatro servicios y verifica las versiones. Dentro de Kali sin internet, con Docker y el archivo de imágenes ya preparados, usa `bash deploy.sh --offline`. El script no envía solicitudes para provocar las CVE.

Para usar otra Kali con internet, clona este repositorio, entra en la carpeta y ejecuta `./deploy.sh`. El paquete de imágenes de `offline/` se distribuye aparte porque está excluido de Git.

## Requisitos

- Kali Linux en una VM VirtualBox con Docker Engine, el complemento Docker Compose, `curl` y `sha256sum`.
- Recursos suficientes en la VM para Kali y los contenedores. Como punto inicial de planificación, reserva aproximadamente **4 GiB de RAM para la VM**; prueba con **6–8 GiB** si ejecutarás ambas versiones a la vez. Ajusta según las mediciones de la clase y la capacidad del computador.
- Imágenes preparadas antes de entrar en la red sin internet. Las imágenes PHP y HAProxy son de terceros; verifica sus digests antes de distribuirlas.

## Preparación con internet, antes de la clase

```bash
cp .env.example .env
bash scripts/lab.sh build
bash scripts/offline.sh export
```

El comando de compilación obtiene la imagen oficial HAProxy y construye las dos imágenes PHP desde etiquetas oficiales. El archivo `offline/php2shell-images-8.4.26-8.4.27.tar` y su `.sha256` permiten distribuir las tres imágenes necesarias. Conserva también este repositorio y registra los digests reales usados; las etiquetas por sí solas pueden cambiar.

## Uso sin internet dentro de Kali

Si recibiste el archivo de imágenes en lugar de prepararlas en tu VM:

```bash
bash scripts/offline.sh import
```

Después puedes usar un solo comando:

```bash
bash deploy.sh --offline
```

Para ejecutar las verificaciones por separado:

```bash
bash scripts/lab.sh start
bash scripts/verify.sh
bash scripts/lab.sh status
bash tests/isolation.sh
```

Abre `http://127.0.0.1:8081/` para PHP 8.4.26 y `http://127.0.0.1:8082/` para PHP 8.4.27 **desde Kali**. La página no anuncia su versión en el contenido; el alumno la descubre en la cabecera HTTP `X-Powered-By`. Si esos puertos están ocupados, edita `.env` antes de iniciar los servicios. El sistema anfitrión y los demás alumnos no comparten estos puertos: `127.0.0.1` se refiere a la VM Kali.

Comandos de operación:

```bash
bash scripts/lab.sh versions
bash scripts/lab.sh logs vulnerable
bash scripts/lab.sh snapshot vulnerable
bash scripts/lab.sh restart vulnerable
bash scripts/lab.sh reset vulnerable
bash scripts/lab.sh stop
```

`reset` toma una copia de estado y registros en `evidence/`, elimina el contenedor elegido y lo recrea sin reconstruir la imagen. No afecta al otro servicio PHP. `stop` detiene el proyecto. Los archivos dentro de `evidence/` son locales y están excluidos de Git.

## Diseño y límites

Las dos imágenes usan la misma carpeta `app/public/`, `config/php/lab.ini` y `config/apache/lab.conf`. Dos pasarelas HAProxy en modo TCP dejan pasar el tráfico sin reescribir HTTP; cada una conecta el puerto local de Kali con una sola red Docker interna. Los contenedores PHP no tienen puertos publicados directamente ni montajes de archivos del anfitrión. Consulta [la arquitectura](docs/architecture.md) y [la resolución de problemas](docs/troubleshooting.md). La [guía de operación manual](docs/manual-testing.md) explica la preparación de Kali, la captura de evidencia y la recuperación. `bash scripts/capture.sh <etiqueta>` registra ambas versiones sin generar pruebas de las CVE.

Los contenedores PHP tienen un límite inicial de 512 MiB y un CPU cada uno. El `memory_limit` de PHP es 128 MiB. Son parámetros de partida que deberán medirse en la **Fase 4**; un límite de contenedor demasiado bajo puede matar el proceso antes de que PHP produzca un diagnóstico útil. El proceso maestro de la imagen oficial Apache conserva los privilegios requeridos por su configuración de puerto 80; esto es un riesgo residual dentro de una VM dedicada.

## Estado de validación

El 22 de octubre de 2026 se reconstruyeron y arrancaron las imágenes en Docker Desktop con el portal Archivo Costero. Pasaron las verificaciones de versiones HTTP, cargas multipart benignas y separación entre contenedores. Consulta [el estado de la Fase 4](docs/validation-status.md) para ver el alcance y las pruebas pendientes en Kali. Ningún resultado de explotación se declara verificado aquí.

