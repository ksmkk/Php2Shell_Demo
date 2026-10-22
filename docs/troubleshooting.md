# Diagnóstico operativo en Kali

Trabaja desde la raíz del repositorio. Usa `bash scripts/lab.sh status` para ver los cuatro contenedores y `bash scripts/verify.sh` para revisar ambas versiones y puertos.

| Síntoma | Comprobación | Acción |
|---|---|---|
| Docker no responde | `docker info` | Inicia el motor Docker de Kali y vuelve a comprobar. |
| Compose no está instalado | `docker compose version` | Instala el complemento antes de la clase; no dependas de descargas en la sala. |
| Imagen inexistente | `docker image ls` | Importa el archivo offline con `bash scripts/offline.sh import`. |
| Puerto ocupado | `ss -ltn` y `cat .env` | Cambia el puerto correspondiente en `.env` y vuelve a iniciar. |
| Pasarela activa, PHP caído | `bash scripts/lab.sh status` y `bash scripts/lab.sh logs vulnerable` | Guarda evidencia y usa `restart` o `reset` para ese servicio. |
| No hay respuesta HTTP | `curl -v http://127.0.0.1:8081/health.php` | Revisa los registros de PHP y la pasarela, y comprueba el puerto de `.env`. |
| Un contenedor se quedó sin memoria | `docker inspect` o `bash scripts/lab.sh snapshot vulnerable` | Conserva el estado antes del reinicio. Distingue OOM de PHP del OOM del contenedor. |

La dirección `127.0.0.1` se interpreta dentro de Kali. Abrirla en el sistema anfitrión de VirtualBox no llega a la VM. Si la pasarela no obtiene la dirección del contenedor después de `reset`, revisa `bash scripts/lab.sh logs vulnerable` y el estado de `gateway-vulnerable` antes de reiniciar solo esa pasarela.

Un fallo del control de salud, un error de carga y una caída de Apache son observaciones diferentes. Anota el código de salida y los registros antes de concluir si hubo un fallo de PHP, agotamiento del límite del contenedor o un problema de red.

