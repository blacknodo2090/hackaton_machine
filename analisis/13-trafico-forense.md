# Plan de análisis 13 — Tráfico y forense de red
- **Punto de vista:** Analista ofensivo-forense que recibe una captura (.pcap/.pcapng/USB/TLS) de un CTF autorizado y debe reconstruir sesiones, extraer artefactos y llegar a la bandera. Es una metodología genérica; no investiga ningún objetivo concreto.
- **Cuándo aplicarlo:** El reto entrega un archivo de captura, o un binario/log que contiene tráfico de red (HTTP, FTP, DNS, ICMP, USB, TLS con clave). Aplica también cuando hay sospecha de exfiltración o de credenciales en claro.

## Preparación
1. **Confirmar alcance.** Verificar que existe `ctf/SCOPE.md` confirmado antes de tocar cualquier captura del evento (ver sección Autorización).
2. **Trabajar sobre copia.** Copiar la captura a un directorio nuevo y dejar el original de solo lectura. Calcular hash (`certutil -hashfile captura.pcapng SHA256` en Windows, `sha256sum` en Linux/WSL) para citarlo en el informe.
3. **Separar carpetas de salida.** Usar un directorio por ejecución (`out_http`, `out_dns`, etc.) para no mezclar artefactos ni sobrescribir resultados.
4. **Inventario de entorno.** Confirmar versión de Wireshark/tshark (`tshark -v`) porque los nombres de campos cambian entre versiones.
5. **Ficheros adicionales.** Buscar claves TLS (`*.log` con `CLIENT_RANDOM` o `CLIENT_TRAFFIC_SECRET`), listas de contraseñas, mapas de teclado USB o instrucciones dentro del reto. Si hay clave RSA privada, anotarla para descifrado de TLS 1.2 con RSA.
6. **Tipo real del archivo.** Comprobar magia con `file captura` y `capinfos captura` (enlaces de tipo, snaplen, número de paquetes, rango temporal).

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| Wireshark (GUI) | Inspección visual, Follow Stream, Export Objects, descifrado TLS con keylog | Windows nativo (instalador oficial, incluye tshark y editcap). Kali: `apt install wireshark` |
| tshark | Versión CLI de Wireshark: filtros, campos, export de objetos, estadísticas (`-z`) | Windows nativo (viene con Wireshark). Kali nativo |
| capinfos / editcap / mergecap | Metadatos, conversión pcapng→pcap, unión/corte de capturas | Windows nativo (con Wireshark). Kali nativo |
| NetworkMiner | Extracción automática de ficheros, imágenes, credenciales y hosts desde PCAP | Windows nativo (aplicación .NET). Kali: no es el uso habitual |
| tcpflow | Reconstrucción de flujos TCP a ficheros, una salida por conexión | Sin binario Windows oficial; usar WSL/Kali. Kali: `apt install tcpflow` |
| Zeek | Logs por protocolo (`conn.log`, `dns.log`, `http.log`, `files.log`) y extracción de ficheros por scripts | Sin binario Windows; usar WSL/Kali. Kali: `apt install zeek` o paquete oficial |
| Scapy (Python) | Parseo a medida, scripting de campos, reensamblado propio, extracción de payload | Windows nativo con Python (`pip install scapy`), con limitaciones para captura en vivo. Kali nativo |
| foremost / scalpel / bulk_extractor | Talla de ficheros por cabeceras en datos crudos o en un volcado extraído | Kali/WSL (`apt install foremost`). Windows: no verificado |
| binwalk / strings / xxd | Buscar ficheros embebidos, cadenas, hex en payloads extraídos | Kali/WSL nativo; `strings` y `xxd` también disponibles en varias distribuciones de Windows vía Git Bash o WSL |
| USBPcap | Captura de tráfico USB en Windows (formato pcap compatible con Wireshark) | Windows nativo (se instala con Wireshark). Linux usa `usbmon` |
| CyberChef | Decodificar base64, hex, XOR, gzip sobre el texto extraído | Web local o en navegador, sin instalación |
| Python `pyshark` | Wrapper de tshark para scripts | Windows y Kali (requiere tshark instalado) |

> **Catálogo Kali:** ver [KALI_CATALOG.md](../docs/tools/KALI_CATALOG.md) → Forensics · Collection · Exfiltration.

## Procedimiento paso a paso

1. **Metadatos y tipo de captura.** Confirmar formato, enlaces y rango temporal.
   ```bash
   capinfos captura.pcapng
   ```
   Hace un resumen de número de paquetes, duración, encapsulado y tamaño de snaplen. Si el snaplen es corto, los payloads pueden estar truncados.

2. **Conversión opcional a pcap clásico.** Algunas herramientas (p. ej. tcpflow o ciertos scripts de Scapy) prefieren pcap.
   ```bash
   editcap -F pcap captura.pcapng captura.pcap
   ```
   Convierte el formato. Conserva los paquetes; no es imprescindible si la herramienta soporta pcapng. [Fuente de la conversión: HackTricks, apartado PCAP vs PCAPNG.]

3. **Jerarquía de protocolos.** Mapa rápido de lo que hay en la captura.
   ```bash
   tshark -r captura.pcapng -q -z io,phs
   ```
   Lista protocolos y volumen por capa. Señala HTTP, FTP, DNS, ICMP, TLS, USB o protocolos raros (p. ej. tráfico en puertos no estándar).

4. **Conversaciones y endpoints.** Identifica pares de IP y puertos más activos.
   ```bash
   tshark -r captura.pcapng -q -z conv,tcp
   tshark -r captura.pcapng -q -z endpoints,ip
   ```
   Muestra conexiones TCP con bytes y paquetes por flujo. Prioriza flujos con mucho volumen o puertos atípicos.

5. **Seguir un flujo TCP (reconstrucción de sesión).** Equivale a "Follow TCP Stream" de Wireshark.
   ```bash
   tshark -r captura.pcapng -q -z "follow,tcp,ascii,0"
   tshark -r captura.pcapng -q -z "follow,tcp,raw,0"
   ```
   `ascii` muestra el texto de la sesión (cabeceras HTTP, comandos FTP). `raw` devuelve el contenido en hex, útil para binarios. El índice `0` es el número de stream: ver con `-z conv,tcp` o con el campo `tcp.stream`.

6. **Exportar objetos HTTP (ficheros transferidos).**
   ```bash
   tshark -r captura.pcapng --export-objects "http,out_http"
   ```
   Guarda en `out_http` los cuerpos HTTP reconocidos (HTML, imágenes, ejecutables, etc.). Se recomienda crear el directorio antes. Limitación: si el nombre es muy largo, la exportación puede fallar. Hay casos reportados de "Some files could not be saved" por nombre largo. [Fuente: Ask Wireshark.]
   Equivalente GUI: File → Export Objects → HTTP.
   Para otros protocolos, el mismo patrón sirve con `smb`, `imf` (correo), `tftp`, `dicom`, según versión instalada. Verificar con `tshark --export-objects help`.

7. **Extraer campos concretos.** Consultar campos en lugar de leer el tráfico a mano.
   ```bash
   tshark -r captura.pcapng -Y "http.request" -T fields -e ip.src -e http.host -e http.request.method -e http.request.uri
   ```
   Lista las peticiones HTTP con origen, host, método y URI. Útil para localizar rutas sospechosas, cabeceras o parámetros.

8. **Credenciales en claro.** Buscar autenticación en protocolos sin cifrar.
   ```bash
   tshark -r captura.pcapng -Y "ftp.request.command in {\"USER\" \"PASS\"}" -T fields -e ftp.request.command -e ftp.request.arg
   tshark -r captura.pcapng -Y "http.authorization" -T fields -e ip.src -e http.authorization
   tshark -r captura.pcapng -Y "urlencoded-form" -T fields -e ip.src -e urlencoded-form.key -e urlencoded-form.value
   ```
   Recoge FTP (USER/PASS), Basic Auth de HTTP (base64 que se decodifica con `echo ... | base64 -d`) y formularios POST con `urlencoded-form`. Los campos exactos dependen de la versión; comprobar con `tshark -G fields | findstr http` (Windows) o `tshark -G fields | grep http` (Linux/WSL).

9. **Exfiltración por DNS.** Buscar consultas con subdominios largos o codificados.
   ```bash
   tshark -r captura.pcapng -Y "dns.flags.response==0" -T fields -e frame.time_relative -e dns.qry.name | sort -u
   ```
   Lista consultas DNS. Señales: nombres muy largos, muchas consultas a un único dominio padre, subdominios en base32/base64/hex. Para concatenar la carga, extraer el prefijo (`cut -d. -f1`), ordenar por tiempo y decodificar. Revisar también tipos de registro inusuales (TXT, NULL) con `-e dns.qry.type`.

10. **Exfiltración por ICMP.** Buscar payloads en echo request/reply.
    ```bash
    tshark -r captura.pcapng -Y "icmp" -T fields -e ip.src -e ip.dst -e data.data
    ```
    `data.data` contiene el payload en hex. Si el reto usa ICMP, es habitual que cada paquete lleve un fragmento. Comprobar si el payload repite un patrón o tiene relleno fijo.

11. **Descifrado TLS con claves dadas.** Requiere un keylog compatible (formato NSS, `SSLKEYLOGFILE`).
    ```bash
    tshark -o "tls.keylog_file:claves.log" -r captura.pcapng -Y "http" -T fields -e ip.src -e http.request.uri
    ```
    El preferencia `tls.keylog_file` indica a Wireshark el fichero de secretos; la wiki oficial documenta este mecanismo. [Fuente: wiki.wireshark.org/TLS.] Si la clave está en formato TLS 1.2 (`CLIENT_RANDOM`), el descifrado es directo. En TLS 1.3 se requieren secretos de tráfico (`CLIENT_TRAFFIC_SECRET_0`, `SERVER_HANDSHAKE_TRAFFIC_SECRET`, etc.). Sin el handshake completo en la captura, no hay descifrado.
    Para TLS con clave RSA privada (sin ECDHE), la clave se puede cargar en Wireshark en Preferences → TLS → RSA keys; esto solo sirve si el intercambio es RSA. [Fuente de matiz: Didier Stevens, blog.didierstevens.com/2020/12/28 — no verificado con el detalle completo.]
    Diagnóstico: `-o tls.debug_file:tls.log` (no verificado en este informe; comprobar con la documentación de la versión).

12. **Captura USB.** Extraer datos de HID (teclado o ratón).
    ```bash
    tshark -r usb.pcapng -Y "usb.capdata" -T fields -e frame.number -e usb.capdata
    tshark -r usb.pcapng -Y "usb.data_len == 8" -T fields -e usb.capdata
    ```
    El primer comando lista el payload de cada transferencia. El segundo filtra informes de 8 bytes, típicos de teclado. En un informe de teclado HID, el byte 2 (índice 2) suele contener el keycode (0x00–0xE7). Mapear códigos con la tabla de uso HID. Los writeups de CTF usan también `usb.transfer_type == 0x01` (interrupt) para acotar. [Fuentes: wiki.wireshark.org/CaptureSetup/USB; ctftime.org/writeup/17233; ctftime.org/writeup/39870.] Si la captura viene de Windows, el origen es USBPcap; en Linux, usbmon.

13. **Búsqueda de artefactos en datos extraídos.** Trabajar sobre los ficheros ya exportados.
    ```bash
    file out_http/*
    strings -n 8 out_http/archivo
    binwalk -e out_http/archivo
    foremost -i captura.pcapng -o carve -t all
    ```
    `file` identifica tipos reales. `strings` busca texto. `binwalk -e` extrae ficheros embebidos. `foremost` talla ficheros por cabeceras en datos crudos. [Fuente de foremost: SANS blog, "pulling binaries from pcaps", no verificada en detalle.]

14. **Herramientas automáticas (complementarias, no sustitutivas).**
    - NetworkMiner (Windows): arrastrar la captura, revisar pestañas Files, Images, Credentials, Sessions.
    - Zeek (WSL/Kali): `zeek -r captura.pcapng` genera logs `conn.log`, `dns.log`, `http.log`, `files.log` en el directorio de trabajo. Para extraer ficheros de forma automática, usar el script de extracción de Zeek (verificar el nombre exacto en la versión instalada).
    - tcpflow (WSL/Kali): `tcpflow -r captura.pcapng -o flujos` deja un fichero por flujo, con nombres que codifican IP y puerto.
    - Scapy (Python, verificar): para casos a medida, `rdpcap("captura.pcap")` y recorrer `Raw` o `TCP` por paquete.

## Qué buscar (indicadores / artefactos)

- **Protocolos en claro:** FTP (USER/PASS/RETR/STOR), HTTP Basic, cookies de sesión, formularios POST, Telnet, SMTP AUTH, POP3, IMAP.
- **Ficheros transferidos:** HTTP/SMB/TFTP/IMF; firmas de cabecera (`file`), ficheros comprimidos, imágenes con datos al final (tras `FFD9` o `IEND`).
- **DNS:** subdominios largos, muchas consultas a un mismo padre, TXT/NULL inusuales, respuestas con datos.
- **ICMP:** payloads en echo request/reply, tamaños constantes, datos legibles o hex repetido.
- **TCP:** flujos con retransmisiones o huecos (uso de `-z expert` para ver anomalías), puertos no estándar con protocolos mal identificados (para forzarlo: `-d tcp.port==8080,http`).
- **TLS:** versión (1.2 o 1.3), presencia de `Client Hello`/`Server Hello`, cipher suites, SNI (`tls.handshake.extensions_server_name`).
- **USB:** dispositivo (interfaz HID), transferencias de interrupción de 8 bytes, pulsaciones que siguen un patrón de tiempo.
- **Estadísticas:** picos de tráfico, IPs o puertos fuera de lo esperado, horarios anómalos.

## Cómo interpretar y extraer la bandera

1. **Orden de sospechas.** Primero texto plano (`follow,tcp,ascii`), después objetos exportados, después campos concretos (DNS/ICMP/USB), y por último descifrado o carving. Así se llega antes a la bandera en retos típicos.
2. **Buscar la bandera en todo el material.** Usar `grep` sobre los volcados (`grep -ri "flag\|ctf\|{" out_*`) y sobre los `strings` de los objetos extraídos. Es común que la bandera aparezca en base64 o en un fichero comprimido.
3. **Reensamblar por orden temporal o de secuencia.** En DNS e ICMP, ordenar por `frame.time_relative` o por número de secuencia del payload. En TCP, usar siempre el stream reensamblado y no paquetes sueltos.
4. **Decodificar capas.** Base64, hex, XOR con clave corta (probar con CyberChef o un script de fuerza bruta de un byte), gzip/zlib, y luego ficheros embebidos (`binwalk -e`).
5. **Validar.** Confirmar que la bandera tiene el formato esperado (p. ej. `CTF{...}`) y anotar el paso exacto que la produjo: stream, paquete y comando. Esto permite reproducirla y justificarla en el informe.
6. **Registrar.** Guardar capturas filtradas (`tshark -r in -Y "..." -w salida.pcapng`) y los comandos usados.

## Errores comunes y trampas

- **Filtros de visualización vs. de captura.** `-Y` es filtro de visualización; `-f` es BPF de captura. Usar el equivocado no filtra lo que se espera.
- **Versiones y nombres de campo.** Los nombres de campo cambian entre versiones de Wireshark. Si un `-e` sale vacío, comprobar con `tshark -G fields`.
- **Comillas en PowerShell.** En Windows, los filtros con comillas dobles anidadas fallan. Usar comillas simples externas en Git Bash/WSL o escapar en PowerShell (`\"`). Preferir WSL para pipelines con `sort`, `cut` y `base64`.
- **Export Objects no es total.** Solo exporta lo que el dissector reconoce. Si HTTP va sobre un puerto raro, usar `-d tcp.port==PUERTO,http` antes de exportar.
- **Segmentación.** Un objeto HTTP puede estar partido en varios paquetes o con `Transfer-Encoding: chunked` y `Content-Encoding: gzip`. Si el fichero exportado está corrupto, revisar el stream completo con `follow,tcp,raw`.
- **Nombres de fichero largos.** La exportación puede fallar sin mensaje claro. Ver la lista de `--export-objects` en lugar de confiar solo en nombres.
- **TLS sin handshake.** Si la captura empieza a mitad de sesión, no hay forma de descifrar. Verificar que `Client Hello` aparezca en la captura.
- **TLS 1.3 con clave RSA.** Una clave privada RSA no descifra TLS 1.3 con ECDHE. Buscar el keylog.
- **Confundir la fuente de la bandera.** Los datos repetidos o de relleno (p. ej. ICMP con patrón fijo) pueden ser señuelos. Contrastar con otro flujo antes de concluir.
- **Interfaz Windows.** NetworkMiner y Wireshark GUI en Windows pueden no mostrar bien rutas largas; copiar la captura a una ruta corta.
- **Truncado por snaplen.** Un snaplen bajo corta payloads grandes; no hay forma de recuperar lo que no se capturó.
- **Encapsulado.** VLAN, GRE, VXLAN o tráfico dentro de túneles pueden ocultar los dissectors. Usar `-V` o desencapsular antes de analizar.
- **Confiar en la GUI sin verificar.** Las estadísticas automáticas de NetworkMiner pueden omitir ficheros. Contrastar con tshark.

## Fuentes

- Wireshark, TLS (descifrado, keylog, `tls.keylog_file`): https://wiki.wireshark.org/TLS (verificado en búsqueda)
- Wireshark, captura USB (usbmon, USBPcap): https://wiki.wireshark.org/CaptureSetup/USB (verificado en búsqueda)
- Wireshark Q&A, exportación de objetos HTTP desde línea de comandos: https://ask.wireshark.org/questions/35846/how-can-i-export-http-objects-via-command-line (verificado en búsqueda; comunidad, no documentación oficial)
- Wireshark Q&A, error de nombres largos en export: https://www.wireshark.org/lists/wireshark-users/201709/msg00012.html (verificado en búsqueda)
- HackTricks, Pcap Inspection: https://book.hacktricks.xyz/generic-methodologies-and-resources/basic-forensic-methodology/pcap-inspection (verificado en búsqueda; agregador de técnicas, no oficial)
- ctftime, writeup de teclado USB: https://ctftime.org/writeup/17233 (verificado en búsqueda)
- ctftime, writeup USB keyboard (HTB CyberApocalypse 2021): https://ctftime.org/writeup/27705 (verificado en búsqueda)
- ctftime, writeup USB keyboard: https://ctftime.org/writeup/39870 (verificado en búsqueda)
- Netresec, comparación de herramientas de extracción de ficheros desde PCAP: https://netresec.com/?b=255329f (verificado en búsqueda)
- Netresec, NetworkMiner: https://www.netresec.com/ (verificado en búsqueda; la descripción detallada viene de la documentación de SOC: https://soc.readthedocs.io/en/latest/networkminer.html)
- SANS, extracción de binarios desde PCAP: https://sans.org/blog/pulling-binaries-from-pcaps (verificado en búsqueda; no revisado en detalle)
- Didier Stevens, descifrado TLS RSA: https://blog.didierstevens.com/2020/12/28 (verificado en búsqueda; secundario)
- Ckb-next, guía de captura USB en Linux: https://github.com/ckb-next/ckb-next/wiki/USB-Capture-Setup (verificado en búsqueda)

**No verificado en esta investigación:** documentación oficial de tcpflow, Zeek (nombre exacto del script de extracción), Scapy, foremost en Windows, opciones `tls.debug_file` y `-d tcp.port==...,http`. Confirmar cada opción con `tshark -h`, `man tcpflow` o la documentación de la versión instalada antes de usarla en un reto.

## Relación con otros planes

- **Plan 02 (red-conexiones):** Si el reto implica escaneo, mapeo o conexiones en vivo, el plan 02 cubre la fase previa y puede generar la captura que este plan analiza.
- **Plan 01 (fisico-hardware):** Las capturas USB de este plan dependen de un dispositivo físico o de un adaptador; el plan 01 trata la parte de hardware.
- **Plan 05 (bases-datos-consultas):** Las credenciales y consultas SQL extraídas de HTTP/SQL en claro pueden alimentar el plan 05.
- **Plan 07 (osint-reconocimiento):** Los dominios, IP o nombres de host de DNS y SNI pueden aportar contexto de reconocimiento.
- **Plan 08 (ingenieria-social):** Si la captura contiene correos (IMF/SMTP) o mensajes, el contenido puede ser un vector de ingeniería social dentro del reto.

Las relaciones son sugeridas a partir de los títulos de los planes existentes; no se ha revisado su contenido en detalle.

## Autorización

- Este plan es una metodología genérica. No investiga ni ataca ningún objetivo concreto.
- Antes de aplicarlo a una captura de un evento concreto, verificar que existe `ctf/SCOPE.md` confirmado y que la captura pertenece al alcance del evento.
- Si la captura proviene de un sistema real fuera de alcance, no analizarla y reportarlo.
- Las recomendaciones de este plan son propuestas pendientes de aprobación del equipo.
