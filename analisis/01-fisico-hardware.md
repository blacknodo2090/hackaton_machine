# Plan de análisis 01 — Físico y hardware

- **Punto de vista:** analiza el objetivo por su capa física: acceso directo al dispositivo, puertos y buses (USB, UART/serie, JTAG/SWD, SPI/I2C), arranque (BIOS/UEFI, bootloader), firmware extraído de memoria flash, periféricos (teclado, lector RFID/NFC) y mecanismos de bloqueo (pantalla, PIN, fusibles de lectura). En CTF es la vía de entrada de los retos de hardware, IoT y firmware: el reto entrega una placa, un volcado `.bin`, una imagen de firmware o un dispositivo con puertos expuestos.
- **Cuándo aplicarlo:** el reto incluye un dispositivo físico, una placa con pines o pads sin etiquetar, un volcado de memoria flash o de firmware, una imagen de router/cámara/cerradura, una tarjeta o llavero RFID/NFC, un portátil o PC con BIOS/UEFI, o una pantalla o equipo con bloqueo que hay que superar. También cuando el reconocimiento de red (`02-red-conexiones.md`) no ofrece superficie y el dispositivo es el vector.

## Preparación
- **Autorización:** confirmar que el objetivo figura en `ctf/SCOPE.md` confirmado antes de tocar el dispositivo. Sin ello, solo se analizan los ficheros que el reto entrega, sin conectar nada.
- **Copia de seguridad antes de escribir:** toda operación que escribe en flash, reflashea o modifica firmware debe ir precedida de una lectura completa y de su hash (`sha256sum`). Sin volcado original no hay vuelta atrás.
- **Ritmo y daño:** los pasos que desoldan, aplican tensión incorrecta o hacen glitching pueden inutilizar el dispositivo del reto. Confirmar con el organizador si el hardware es reemplazable.
- **Tensión y pines:** medir con multímetro la alimentación (3,3 V o 1,8 V habitual) y la masa antes de conectar un adaptador. Un GND/VCC invertido puede dañar la placa (advertencia de HackTricks, ver Fuentes).
- **Entorno:**
  - Windows nativo: PowerShell, Administrador para CHIPSEC, drivers de programador USB (p. ej. WinUSB con Zadig para CH341A; no verificado en fuente consultada), PuTTY o similar para serie.
  - Kali o WSL: `binwalk`, `flashrom`, `esptool`, `screen`/`minicom` y acceso USB directo. En WSL2 el USB requiere `usbipd-win` (supuesto, no verificado en fuente consultada).
  - Directorio de trabajo: `resultados/<objetivo>/hardware/` con volcados, hashes y capturas de serie.

## Herramientas
| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| binwalk | Escaneo de firmware por firmas, extracción (`-e`, `-M`), entropía (`-E`). | Kali/WSL: sí. Windows: no verificado; usar WSL. |
| flashrom | Lectura, escritura y verificación de chips SPI/flash (`-r`, `-w`, `-v`), con programadores como `ch341a_spi` o `internal`. | Kali/WSL: sí. Windows: no verificado (builds externos). |
| CH341A (programador SPI USB) | Hardware barato para leer chips SPI en placa desoldada o con clip SOIC8. | Hardware; el driver depende del SO. |
| CHIPSEC | Auditoría de seguridad de plataforma PC: protecciones de escritura de BIOS/SPI y firmware. | Windows: sí (como Administrador). Linux: sí (root). Según el repositorio oficial. |
| esptool | Lectura y escritura de flash de dispositivos Espressif (ESP32, ESP8266). | Multiplataforma (Python). |
| Puerto serie (PuTTY, `screen`, `minicom`) | Consola UART a 115200 baud o la velocidad del dispositivo. | Windows: PuTTY o `mode`/terminal. Kali: `screen`, `minicom`. |
| Bus Pirate / adaptador USB-serie (FTDI, CP2102) | Interfaz UART/SPI/I2C de bajo coste, identificación de pines. | Hardware; multiplataforma. |
| JTAGulator / JTAGenum | Identificación de pines JTAG en placas desconocidas. | Hardware; JTAGenum en Arduino. |
| OpenOCD | Depuración JTAG/SWD sobre adaptadores compatibles. | Multiplataforma (no verificado en esta investigación). |
| Sigrok / PulseView + analizador lógico | Captura y decodificación de buses (UART, SPI, I2C). | Multiplataforma (no verificado en esta investigación). |
| Multímetro / osciloscopio | Identificar GND, VCC y niveles de señal. | Hardware. |
| Proxmark3 | Lectura y clonación de RFID/NFC de baja frecuencia y 13,56 MHz (no investigado en esta fuente). | Multiplataforma (no verificado en esta investigación). |
| ChipWhisperer | Fault injection y glitching (no investigado en esta fuente). | Multiplataforma (no verificado en esta investigación). |

## Procedimiento paso a paso
Orden: de lo no invasivo a lo invasivo. Sustituir rutas y nombres por los del reto.

1. **Inventario del fichero entregado (sin hardware).** Identifica tipo y estructura de un volcado o firmware.
   ```bash
   file firmware.bin
   binwalk firmware.bin
   ```
   Qué hace: `file` da el tipo general; `binwalk` escanea firmas (cabeceras de SquashFS, gzip, LZMA, U-Boot, ELF...) y muestra desplazamientos. Documentado: escaneo por defecto (Quick Start, ver Fuentes).

2. **Extracción y análisis recursivo.**
   ```bash
   binwalk -e firmware.bin
   binwalk -Me firmware.bin
   ```
   Qué hace: `-e` extrae los ficheros reconocidos; `-Me` extrae y vuelve a escanear recursivamente lo extraído. Documentado en el Quick Start oficial de ReFirmLabs. Ejecutar en un directorio vacío y sin privilegios de root (advertencia del manual de binwalk según el resumen de búsqueda; no verificado en la página completa).

3. **Entropía (detectar cifrado o compresión).**
   ```bash
   binwalk -E firmware.bin
   ```
   Qué hace: un plano de entropía alto y constante sugiere datos cifrados o comprimidos; baja entropía con picos, datos o tablas sin cifrar. Documentado en Quick Start.

4. **Cadenas y credenciales en claro.**
   ```bash
   strings -n 8 firmware.bin | grep -iE "passw|pwd|key|token|root|admin"
   ```
   Qué hace: busca contraseñas, claves y rutas en el volcado o en los ficheros extraídos. Comando estándar, no citado de fuente.

5. **Identificar el chip de flash (con el dispositivo delante).** Leer la marca y el modelo del chip (p. ej. W25Q64, MX25L). Consultar la lista de chips soportados por flashrom.
   ```bash
   flashrom -L
   flashrom -p ch341a_spi -V
   ```
   Qué hace: `-L` lista programadores y chips soportados; con `-V` (verbose) flashrom intenta detectar el chip conectado. Según la documentación oficial de flashrom, `-V` puede repetirse hasta tres veces. Advertencia: el listado de programadores varía por versión.

6. **Volcado de la flash con el programador externo (dos lecturas para comparar).** Desconectar la alimentación del dispositivo antes de conectar el clip, según práctica habitual de la comunidad (supuesto, no verificado en fuente consultada).
   ```bash
   flashrom -p ch341a_spi -r lectura1.bin
   flashrom -p ch341a_spi -r lectura2.bin
   sha256sum lectura1.bin lectura2.bin
   ```
   Qué hace: `-r` lee el chip y guarda el contenido. Dos lecturas con el mismo hash confirman que el volcado es estable (sin contacto intermitente). Con `-c "<chip>"` se fuerza el chip cuando la detección falla; el nombre debe coincidir exactamente con `flashrom -L`, sin el prefijo del fabricante (documentación de flashrom).

7. **Volcado desde el propio sistema (solo con permisos y en un equipo de prueba).** Leer la flash interna desde el SO.
   ```bash
   sudo flashrom -p internal -r bios_interna.bin
   ```
   Qué hace: lectura del chip de BIOS/firmware desde el sistema operativo mediante el programador `internal`. Documentado en la referencia de flashrom. Riesgo: no escribir nunca sin volcado de referencia.

8. **Auditoría de protecciones de BIOS/SPI (plataforma PC).**
   ```powershell
   # Windows, PowerShell como Administrador, desde el directorio de CHIPSEC
   python chipsec_main.py -m common.bios_wp
   python chipsec_main.py -m common.spi_lock
   ```
   ```bash
   # Linux, como root
   sudo python3 chipsec_main.py -m common.bios_wp
   sudo python3 chipsec_main.py -m common.spi_lock
   ```
   Qué hace: `common.bios_wp` comprueba si la región BIOS está protegida (SMM-BWP o rangos PR del controlador SPI); `common.spi_lock` comprueba el bloqueo FLOCKDN. Documentado en la documentación del módulo bios_wp de CHIPSEC y en el README del repositorio oficial (uso a riesgo y en sistemas de prueba).

9. **Consola serie (UART) y arranque.** Localizar TX, RX y GND con multímetro o analizador lógico; probar la velocidad habitual (115200 baud, o 9600/57600 según el dispositivo) y observar la salida de arranque.
   ```bash
   screen /dev/ttyUSB0 115200
   ```
   ```text
   # Windows: PuTTY, puerto COMx, velocidad 115200, sin control de flujo
   ```
   Qué hace: abre la consola serie. Si aparece un prompt de login o un shell de root sin autenticación, anotar el hallazgo. Documentado como técnica general en HackTricks (ver Fuentes); comandos concretos no verificados en fuente consultada.

10. **Identificar pines JTAG/SWD.** Usar JTAGulator o JTAGenum para JTAG; en ARM, SWD usa dos líneas (SWDIO y SWCLK). Buscar pads de prueba y cabeceras Tag-Connect.
    Qué hace: identifica el puerto de depuración. HackTricks describe JTAGulator como la opción más rápida y JTAGenum como alternativa barata; SWD son dos pines (SWDIO/SWCLK) según la fuente consultada. Comandos de OpenOCD no verificados en esta investigación.

11. **Dispositivos Espressif (ESP32/ESP8266) por UART.**
    ```bash
    esptool --port /dev/ttyUSB0 read-flash 0 ALL flash.bin
    esptool --port COM3 read-flash 0 ALL flash.bin
    ```
    Qué hace: lee la flash completa; `ALL` autodetecta el tamaño (esptool docs). Requiere modo de descarga (bootloader). Si la conexión falla, `esptool --trace` muestra la interacción serie. Comando de referencia de esptool, probado solo en documentación.

12. **Análisis de buses con analizador lógico (si hay tráfico y no hay firmware).** Capturar UART, SPI o I2C con PulseView/sigrok y decodificar; buscar contraseñas o comandos en claro. No verificado en esta investigación con comandos concretos.

13. **Periféricos de entrada (USB/BadUSB, teclado).** Solo si el reto lo plantea y en un entorno autorizado: un dispositivo HID que inyecta pulsaciones se programa con DuckyScript. Ejemplo mínimo de laboratorio:
    ```text
    REM Ejemplo de laboratorio: abre un bloc de notas y escribe texto
    DELAY 1000
    GUI r
    DELAY 500
    STRING notepad
    ENTER
    ```
    Qué hace: `REM` comentario, `DELAY` pausa en ms, `GUI r` abre "Ejecutar" en Windows, `STRING` escribe texto, `ENTER` pulsa Intro. Sintaxis verificada en docs de Hak5 (quick reference, enlace abajo). Compilar y cargar con el herramienta oficial de Hak5; no probado en esta investigación.

14. **Bloqueo de pantalla o PIN de dispositivo (si el reto lo incluye).** Revisar primero el firmware o el volcado en busca del algoritmo de verificación y de datos de la comprobación (hash, PIN almacenado). No investigado en esta fuente; se trata como fase a completar con un plan específico.

15. **RFID/NFC (lector o tarjeta).** Identificar tecnología (13,56 MHz o baja frecuencia), leer UID y sectores con la herramienta del hardware disponible, y comprobar claves por defecto (p. ej. MIFARE Classic). No investigado en esta fuente; verificar antes de aplicar.

## Qué buscar (indicadores de vulnerabilidad)
- **Consola serie sin autenticación** o con prompt de root al arrancar (UART en IoT, según O'Reilly, ver Fuentes).
- **Volcado con credenciales, claves privadas, tokens o PIN** en texto plano o en un sistema de ficheros extraído.
- **Firmware sin firma o con firma no verificada** (comprobar con binwalk y el arranque del bootloader).
- **Protección de escritura de BIOS/SPI ausente o incompleta:** `common.bios_wp` falla si la protección SMM o los rangos PR no cubren toda la región; `common.spi_lock` marca el bloqueo FLOCKDN no activado (CHIPSEC, ver Fuentes).
- **Depuración activa:** pines JTAG/SWD accesibles, cabeceras de depuración en producción o puertos de test sin proteger.
- **Entropía uniforme alta** en todo el volcado: indica cifrado completo; pasar a claves o al bootloader, no a la extracción de ficheros.
- **Sistema de ficheros conocido** (SquashFS, JFFS2, cramfs) detectado por binwalk: contiene el código de la aplicación, buscar binarios con credenciales o rutas de administración.
- **Interfaz USB HID** que acepta cualquier dispositivo o no pide confirmación (riesgo BadUSB).

## Cómo interpretar y pasar a explotación
- **Consola serie accesible** → pasar a análisis de procesos y ficheros del sistema; si hay shell, usar el plan de post-explotación (`pendiente de nombre`) o el plan de red (`02-red-conexiones.md`) si hay interfaces.
- **Firmware extraído con binario vulnerable** (p. ej. servidor web embebido, binario con `system()` o `strcpy`) → pasar al plan de binarios/pwn (`pendiente de nombre`) para analizar con Ghidra, radare2 o similar. Verificar antes el CVE del componente.
- **Credenciales o claves en el volcado** → probar en el servicio correspondiente (SSH, web, panel) solo dentro del alcance; ver `07-osint-reconocimiento.md` para contexto de reutilización de credenciales.
- **Protecciones de BIOS/SPI débiles** → documentar el hallazgo con la salida de CHIPSEC; cualquier escritura de firmware se hace solo con volcado de referencia y en el entorno autorizado.
- **Bus sin cifrar con datos sensibles** → decodificar con el analizador lógico y extraer el mensaje; pasar al plan de criptografía si está cifrado (`pendiente de nombre`).
- **Entropía alta sin firma conocida** → tratar como cifrado; buscar claves en el propio volcado antes de romper el cifrado.

## Errores comunes y trampas
- **Confundir GND y VCC en UART:** puede dañar la placa; medir siempre con multímetro (HackTricks).
- **Escribir la flash sin lectura de respaldo** o sin verificar el hash: se pierde el original si la escritura falla.
- **Lecturas de flash inestables:** un clip SOIC8 mal conectado produce volcados con bloques corruptos; comparar dos lecturas (paso 6).
- **Programador `internal` con el SO en marcha:** puede verse afectado por el controlador de chipset; no es lo mismo que el programador externo y no siempre funciona.
- **Chip no reconocido por flashrom:** el chip puede no estar en la lista de la versión instalada; probar `-c` con el nombre exacto, o actualizar flashrom.
- **Ejecutar binwalk con `-e` como root:** las versiones recientes avisan de riesgo al extraer como root (resumen de búsqueda, no verificado en la página completa). Usar un usuario sin privilegios.
- **Extraer un volcado sin reconocer la firma:** binwalk puede fallar con firmware cifrado o con offset desplazado; revisar la entropía antes de concluir.
- **Nombres de programador o de módulo de otra versión:** flashrom y CHIPSEC cambian entre versiones; usar `flashrom -L` y la documentación de la versión instalada.
- **Tomar la salida de CHIPSEC como concluyente:** los módulos indican protecciones; la explotación requiere demostración en el propio dispositivo.
- **Fallos de USB en WSL2:** sin `usbipd-win` el programador no es visible desde Linux (supuesto, no verificado en fuente consultada).

## Fuentes
- binwalk — ReFirmLabs — https://github.com/ReFirmLabs/binwalk/wiki/Quick-Start-Guide (consultada: `binwalk firmware.bin`, `-e`, `-Me`, `-E`).
- binwalk — Usage (wiki OSPG) — https://github.com/OSPG/binwalk/wiki/Usage (solo snippet de búsqueda; advertencias sobre ejecución como root y `--run-as`, no verificadas en la página completa).
- flashrom man page — Leap 15.6 (openSUSE) — https://manpages.opensuse.org/Leap-15.6/flashrom/flashrom.8.en.html (consultada: `-p`, `-r`, `-w`, `-v`, `-c`, `-V`, `-l`, `-i`, `ch341a_spi`, `internal`).
- flashrom — Supported hardware — https://www.flashrom.org/Supported_hardware (consultada: índice; la lista de programadores está en subpágina no consultada).
- flashrom — CH341A driver docs (Debian sources) — https://sources.debian.org/src/flashrom/1.6.0-2/doc/supported_hw/supported_prog/ch341ab.rst (solo snippet de búsqueda; `flashrom -p ch341a_spi -r`).
- CHIPSEC — repositorio oficial (chipsec) — https://github.com/chipsec/chipsec (consultada: descripción, advertencia de uso a riesgo, `chipsec1` para plataformas Intel antiguas).
- CHIPSEC — módulo common.bios_wp — https://chipsec.github.io/modules/chipsec.modules.common.bios_wp.html (solo snippet: qué comprueba, `python chipsec_main.py -m common.bios_wp`, ejecución como administrador/root).
- CHIPSEC — Running CHIPSEC — https://chipsec.github.io/usage/Running-Chipsec.html (solo listado de resultados de búsqueda; no abierta).
- HackTricks — Hardware Hacking — https://book.hacktricks.xyz/todo/hardware-hacking (la URL redirige a hacktricks.wiki; solo snippet de búsqueda en espejos: JTAGulator, JTAGenum, SWD, UART, GND/VCC).
- Practical IoT Hacking, cap. 7 "UART, JTAG, and SWD Exploitation" — O'Reilly — https://www.oreilly.com/library/view/practical-iot-hacking/9781098128876/c07.xhtml (solo snippet: UART como vía frecuente de acceso root en IoT).
- Basic Commands (read-flash) — Espressif, esptool — https://docs.espressif.com/projects/esptool/en/latest/esp32s2/esptool/basic-commands.html (solo snippet: `read-flash`, `ALL`, `--trace`; ejemplo en ESP32-S2).
- Serial Protocol y Troubleshooting — Espressif, esptool — https://docs.espressif.com/projects/esptool/en/latest/esp32/troubleshooting.html (solo snippet).
- DuckyScript Quick Reference — Hak5 — https://docs.hak5.org/hak5-usb-rubber-ducky/duckyscript-quick-reference (solo snippet: STRING, DELAY, REM; compilación a inject.bin).
- USB Rubber Ducky — Hak5 documentación — https://docs.hak5.org/hak5-usb-rubber-ducky (solo snippet; la web de producto de Hak5 devolvió 429 y no se pudo leer).
- Protecting System Firmware Storage — Eclypsium — https://eclypsium.com/blog/protecting-system-firmware-storage/ (solo snippet: `bios_wp` y `spi_lock` como comprobaciones de protección).
- Ivy Bridge Lenovo ThinkPad Internal Flashing — coreboot — https://doc.coreboot.org/mainboard/lenovo/ivb_internal_flashing.html (solo snippet: uso conjunto de `common.bios_wp` y `common.spi_lock`, FLOCKDN).

No verificado en esta investigación: OpenOCD, sigrok/PulseView, Proxmark3, ChipWhisperer, Zadig y `usbipd-win`. Se citan por nombre como herramientas habituales; sus comandos no se incluyen como probados.

## Relación con otros planes
- `02-red-conexiones.md` — si el dispositivo expone red o tiene interfaces de red, seguir allí para hosts, puertos y pivoting.
- `05-bases-datos-consultas.md` — si el volcado de firmware contiene bases de datos (SQLite, bases embebidas), seguir con sus consultas.
- `07-osint-reconocimiento.md` — búsqueda de firmware público, datasheets y hojas de pines del modelo antes de tocar el hardware.
- Planes de binarios/pwn, criptografía y forense (nombres pendientes de definir en la biblioteca) — destino de binarios extraídos, de cifrado de volcados y de datos de buses.
- Plan de post-explotación (nombre pendiente) — si la consola serie o el arranque dan shell.

Nota: los planes con nombre "pendiente de nombre" aún no existen en `analisis/`; son propuestas pendientes de aprobación.

## Autorización
- Es metodología; aplícala a un objetivo solo si figura en un `ctf/SCOPE.md` confirmado.
- Cualquier escritura de flash, glitching, desoldado o inyección de periféricos requiere confirmación explícita del alcance y, cuando el hardware no sea reemplazable, aprobación del organizador.
- Estado de este plan: propuesta pendiente de aprobación del usuario.
