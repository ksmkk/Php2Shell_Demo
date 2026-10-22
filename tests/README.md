# Matriz de validación para la Fase 4

Parte de estas pruebas se ejecutó en Docker Desktop el 22 de octubre de 2026. Falta repetirlas dentro de Kali y verificar el aislamiento desde otra máquina. Cada registro incluirá fecha, digest de imagen, versión de PHP, versión de Docker, memoria de la VM, solicitud o acción realizada, resultado HTTP, estado del proceso y ruta de los registros conservados en `evidence/`.

| Caso | Comprobación | Criterio |
|---|---|---|
| Arranque | Iniciar las cuatro unidades de Compose y ejecutar `scripts/verify.sh` | PHP 8.4.26 y 8.4.27, SAPI `apache2handler`, ambas páginas responden. |
| Independencia | Enviar solicitudes simultáneas a ambos puertos | PID, sesiones, temporales y registros de cada PHP permanecen separados. |
| Reinicio | Reiniciar solo `vulnerable` | `patched` continúa respondiendo. |
| Fallo controlado | Detener solo `vulnerable` | Se observa su indisponibilidad y `patched` sigue disponible. |
| Recuperación | Tomar `snapshot` y ejecutar `reset vulnerable` | La instancia vuelve al estado inicial sin reconstruir imagen. |
| Aislamiento | Ejecutar `bash tests/isolation.sh` y consultar puertos desde otra máquina | Ambos PHP quedan separados, no tienen salida directa y la LAN no alcanza los puertos de Kali. |
| Multipart | Subir un archivo benigno pequeño a ambas versiones | Ambas informan tamaño y el mismo SHA-256. |
| CVE | Ejecutar únicamente pruebas diagnósticas acotadas que se aprueben para Fase 4 | Clasificar error, caída, OOM de contenedor, traza de memoria y efecto del parche sin inferir RCE de una sola señal. |

Las pruebas de corrupción de memoria requieren un protocolo separado, límites definidos y, cuando corresponda, una compilación instrumentada. No se usan cadenas de ejecución remota en esta matriz.

