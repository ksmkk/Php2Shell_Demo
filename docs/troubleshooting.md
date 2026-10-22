# Diagnóstico operativo en Kali

Trabaja desde la raíz del repositorio. Usa `bash scripts/lab.sh status` para ver los cuatro contenedores y `bash scripts/verify.sh` para revisar ambas versiones y puertos.

| Síntoma | Comprobación | Acción |
|---|---|---|
| `docker --version` funciona, pero `deploy.sh` dice que no conecta | `docker info`, `sudo docker info`, `sudo systemctl status docker` | La versión solo confirma el cliente. Si el servicio está detenido, `sudo systemctl start docker`; si funciona con `sudo` pero no con tu usuario, revisa el acceso al socket Docker. |
| Faltan Docker o Compose en Kali | `command -v docker` y `docker compose version` | Con internet, `bash deploy.sh` instala los paquetes de Kali ausentes mediante `apt` y `sudo`. `--offline` se detiene sin instalar. |
| Compose no está instalado | `docker compose version` | Instala el complemento antes de la clase; no dependas de descargas en la sala. |
| Imagen inexistente | `docker image ls` | Importa el archivo offline con `bash scripts/offline.sh import`. |
| Puerto ocupado | `ss -ltn` y `cat .env` | Cambia el puerto correspondiente en `.env` y vuelve a iniciar. |
| Pasarela activa, PHP caído | `bash scripts/lab.sh status` y `bash scripts/lab.sh logs vulnerable` | Guarda evidencia y usa `restart` o `reset` para ese servicio. |
| No hay respuesta HTTP | `curl -v http://127.0.0.1:8081/health.php` | Revisa los registros de PHP y la pasarela, y comprueba el puerto de `.env`. |
| Un contenedor se quedó sin memoria | `docker inspect` o `bash scripts/lab.sh snapshot vulnerable` | Conserva el estado antes del reinicio. Distingue OOM de PHP del OOM del contenedor. |

## Docker funciona con `sudo`, pero no con la cuenta `kali`

Si `docker info` muestra `permission denied` para `/var/run/docker.sock` y `sudo docker info` sí muestra el servidor, el motor ya está activo. Falta acceso a su socket para la sesión actual. En una VM Kali dedicada, el administrador puede añadir esa cuenta al grupo `docker`:

```bash
sudo usermod -aG docker "$USER"
```

Cierra sesión por completo y vuelve a entrar; en VirtualBox, reiniciar la VM también actualiza los grupos. Para usar la terminal actual sin reiniciar, ejecuta `newgrp docker`. Después comprueba `id -nG` y `docker info --format '{{.ServerVersion}}'` **sin `sudo`**, y ejecuta `bash deploy.sh`. El grupo `docker` concede privilegios equivalentes a los de administrador sobre la VM; limita esta configuración a la VM del laboratorio. [Referencia: pasos posteriores a la instalación de Docker](https://docs.docker.com/engine/install/linux-postinstall/).

La dirección `127.0.0.1` se interpreta dentro de Kali. Abrirla en el sistema anfitrión de VirtualBox no llega a la VM. Si la pasarela no obtiene la dirección del contenedor después de `reset`, revisa `bash scripts/lab.sh logs vulnerable` y el estado de `gateway-vulnerable` antes de reiniciar solo esa pasarela.

Un fallo del control de salud, un error de carga y una caída de Apache son observaciones diferentes. Anota el código de salida y los registros antes de concluir si hubo un fallo de PHP, agotamiento del límite del contenedor o un problema de red.

