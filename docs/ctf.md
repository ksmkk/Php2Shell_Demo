# Desafío: Archivo Costero

## Escenario

Eres parte del equipo que revisa un portal documental ficticio. Tienes autorización para observar las dos instancias de tu propia VM Kali. El portal de producción simulada está en `http://127.0.0.1:8081/`; la instancia de comparación está en `http://127.0.0.1:8082/`. Ambos puertos solo escuchan en el loopback de Kali.

## Objetivos

1. **Reconocimiento:** identifica servidor, tecnología y versión exacta de cada instancia. Guarda la respuesta HTTP que respalda tu hallazgo. Puedes usar `nmap -sV --script http-headers -p 8081,8082 127.0.0.1` o `curl -I http://127.0.0.1:8081/`. Nmap puede identificar la pasarela o Apache; la cabecera `X-Powered-By` de la respuesta PHP aporta la versión de PHP.
2. **Investigación:** vincula la versión encontrada con el aviso de seguridad documentado en [cve-analysis.md](cve-analysis.md). Anota identificador, versiones afectadas, versión corregida y fuente primaria.
3. **Función del portal:** envía un archivo de prueba mediante la mesa de entrada. Documenta el comprobante y explica qué hace la aplicación con el archivo temporal.
4. **Comparación:** repite la observación en la instancia corregida. Usa `bash scripts/capture.sh antes` y `bash scripts/capture.sh despues` para conservar versiones, PID, estado y registros de ambas instancias. Si realizas una prueba manual de la CVE, describe la solicitud y el resultado sin convertir un error HTTP o una caída en prueba automática de ejecución de código.

## Entrega

Entrega un informe breve con los comandos de reconocimiento, cabeceras relevantes, aviso consultado, una tabla de comparación entre ambos puertos y la carpeta de evidencia local. La evaluación depende de evidencia reproducible y de una conclusión proporcionada a lo observado. No hay una bandera de RCE publicada ni una explotación automática en este repositorio; esa etapa requiere validación manual separada.
