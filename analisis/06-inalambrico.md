# Plan de análisis 06 — Inalámbrico

- **Punto de vista:** análisis de superficies inalámbricas en retos de CTF: Wi-Fi 802.11 (captura del handshake WPA/WPA2, PMKID, deauth, redes abiertas y WEP), Bluetooth/BLE, RF genérico (ISM 433/868/315/915 MHz) y NFC/RFID (MIFARE Classic). Un reto suele dar una captura `.cap`/`.pcapng` con tráfico 802.11, una grabación de radio o una tarjeta/etiqueta, y la bandera sale de recuperar una clave (PSK, clave de sector) o de decodificar un mensaje.
- **Cuándo aplicarlo:** el enunciado o los archivos incluyen `.cap`, `.pcap`, `.pcapng`, `.hc22000`, capturas de BLE, grabaciones IQ/`.cfile`, o un volcado MIFARE (`.mfd`); se menciona Wi-Fi, WPA, router, Bluetooth, llavero, tarjeta de acceso o control remoto; o hay que recuperar una clave que protege una red o un dispositivo y el reto deja un diccionario o una pista de contraseña.

Convención: **[V]** = comprobado en la fuente indicada durante la investigación; **[NP]** = no probado en este entorno, tomado de documentación secundaria o práctica habitual, a validar antes de depender de ello. Sustituye `<BSSID>`, `<CLIENTE>`, `<archivo>` y `<diccionario>` solo después de confirmar el alcance.

## Preparación
- **Alcance:** verifica que el objetivo (BSSID, dispositivo, tarjeta o archivo de captura del reto) figure en un `ctf/SCOPE.md` confirmado. Hoy no existe `ctf/SCOPE.md` en el repositorio [V, comprobado]; sin ese archivo no se investiga ningún objetivo, y este plan es solo metodología. Las capturas de terceros ya entregadas en el reto se analizan offline; la inyección de tráfico (deauth, reinyección) solo contra redes dentro del alcance.
- **Adaptador Wi-Fi con modo monitor e inyección (requisito):** el crackeo offline de un handshake no necesita adaptador, pero capturar en vivo sí. Hace falta una tarjeta cuyo chipset y driver soporten modo monitor y **inyección de tramas completa** [V, hcxdumptool README]. Según ese README, son conocidos como válidos chipsets Realtek (rtl8xxxu, rtw88), Atheros (ath9k_htc, chipsets antiguos) y Ralink (rt2800usb, antiguos); se desaconseja Intel, Broadcom y Qualcomm; MediaTek (mt76) da problemas de modo monitor activo [V]. Verifica el chipset real con `lsusb` (el modelo comercial puede cambiar de chipset sin cambiar de nombre) [V].
- **Linux obligatorio para la captura en vivo:** hcxdumptool solo soporta Linux con kernel ≥ 5.15; Windows, macOS, Android y emuladores están marcados como no soportados [V, README]. aircrack-ng (airmon-ng/airodump-ng/aireplay-ng) también asume Linux [V, docs aircrack-ng].
- **Limitación en Windows / WSL (documentar):**
  - En Windows nativo, Npcap puede capturar 802.11 en crudo solo con adaptadores y drivers que expongan modo monitor; el soporte varía por tarjeta (p. ej. un reporte indica que un Intel AX210 no lo soporta) y WinPcap en conflicto lo bloquea [V/NP: fuentes de foro y wiki de Wireshark; sin documentación oficial de Npcap consultada]. La wiki de Wireshark dice que el cambio de modo 802.11 depende mucho de la plataforma y que en Windows es muy limitado [V, wiki.wireshark.org]. **Conclusión: en Windows nativo, la captura de handshake es poco fiable; úsala solo para ver tramas si el adaptador lo permite.**
  - En WSL2 el adaptador Wi-Fi USB no aparece por defecto; hay que pasarlo con usbipd-win (`usbipd list`, `usbipd bind`, `usbipd attach --wsl`) [NP: la página de Microsoft consultada devolvió 404; no verificado].
  - Recomendación pendiente de aprobación: usar una máquina Kali (VM con USB pasado por completo) para toda la captura en vivo; Windows solo para crackeo offline con hashcat.
- **Crackeo offline en Windows:** hashcat funciona en Windows nativo con la GPU/driver adecuado [NP]. aircrack-ng se usa mejor en Kali/WSL.
- **Registro de trabajo:** carpeta por reto (p. ej. `ctf/<reto>/wireless/`) con las capturas originales sin modificar, los `.hc22000` generados, el diccionario usado y la línea de comandos de cada paso.
- **Hashcat:** comprueba la versión (`hashcat --version`); el modo 22000 existe desde la v6.0.0 [V, hashcat wiki y foro].

## Herramientas
| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| `airmon-ng` (aircrack-ng) | Pone la tarjeta en modo monitor | Solo Linux (Kali nativo o VM con USB) [V, docs aircrack-ng] |
| `airodump-ng` (aircrack-ng) | Escanea redes y clientes; guarda capturas; muestra la nota "WPA handshake" | Solo Linux [V, docs] |
| `aireplay-ng` (aircrack-ng) | Deauth (`--deauth`/`-0`), prueba de inyección (`--test`/`-9`) | Solo Linux, con tarjeta que inyecte [V, docs] |
| `aircrack-ng` | Crackeo WPA/WPA2-PSK por diccionario con el `.cap` | Kali/WSL con apt [V, docs]; en Windows, binarios de terceros [NP] |
| `hcxdumptool` | Captura PMKID y EAPOL con ataques controlados | Solo Linux, kernel ≥ 5.15 [V, README] |
| `hcxpcapngtool` (hcxtools) | Convierte `.pcapng` a `.hc22000` para hashcat | Kali/WSL/Linux [V: `-o hash.hc22000 dumpfile.pcapng`]; compilable en Linux [NP en Windows] |
| `hashcat` | Crackeo offline por GPU (modos 22000, 22001) | Windows nativo y Linux [V: modo 22000; soporte en Windows NP] |
| `tshark` / Wireshark (Npcap) | Inspección de tramas 802.11, EAPOL, PMKID | Windows nativo (con limitación de modo monitor) y Linux [V wiki Wireshark, NP en detalle] |
| `bettercap` (módulos wifi/ble) | Escaneo y enumeración BLE; reconocimiento Wi-Fi | Linux (Kali) [NP para Windows] |
| `bluetoothctl` / `gatttool` | Emparejar, listar servicios y leer/escribir características BLE (gatttool deprecado pero funcional) | Linux (BlueZ) [NP] |
| `ubertooth-btle` + `crackle` | Sniffing BLE con hardware Ubertooth; descifrado de emparejamiento legacy | Linux [NP: man pages, sin ejecutar] |
| `rtl_433` + RTL-SDR | Decodifica señales ISM (433.92 MHz por defecto; 868, 315, 915 MHz) con más de 200 protocolos | Windows y Linux [V: README/manual; compilación en Windows V según resumen, no probada] |
| GNU Radio / `rtl_sdr` / `inspectrum` | Grabar y analizar IQ de RF; demodular manualmente | Linux preferente [NP] |
| `mfoc` / `mfoc-hardnested` | Recuperar claves MIFARE Classic con ataque nested/hardnested | Linux (Kali apt) [V: Kali package page; NP en ejecución] |
| Proxmark3 (Iceman) | Lectura y ataque MIFARE, LF/HF; `hf mf nested` con clave conocida | Cliente Linux/Windows según build [V cheatsheet; NP] |
| libnfc `nfc-list` | Detecta lectores PN532 y etiquetas | Linux [NP; manual oficial no consultado] |

## Procedimiento paso a paso

Ruta A — Wi-Fi WPA/WPA2-PSK (captura del handshake y crackeo offline). Ejecutar en Kali o VM con USB; el crackeo puede hacerse después en otra máquina.

1. **Comprobar la tarjeta y matar procesos que interfieren.**
   ```bash
   iw dev
   sudo airmon-ng check kill
   ```
   `iw dev` lista interfaces. `airmon-ng check kill` termina NetworkManager/wpa_supplicant que cambian de canal [V: el flujo airmon-ng es el descrito en la guía de aircrack-ng; comando exacto NP].

2. **Modo monitor.**
   ```bash
   sudo airmon-ng start wlan0
   iw dev
   ```
   Confirma que aparece `wlan0mon` (o similar). Sin modo monitor no hay datos útiles [V, docs airodump-ng].

3. **Localizar el objetivo (escaneo pasivo).**
   ```bash
   sudo airodump-ng wlan0mon
   ```
   Anota BSSID, canal (`CH`), ESSID y clientes asociados. Mantén el escaneo mientras trabajas.

4. **Captura dirigida de un canal y AP.** Qué hace: fija el canal y filtra por BSSID; escribe la salida con prefijo `captura`.
   ```bash
   sudo airodump-ng -c <CANAL> --bssid <BSSID> -w captura wlan0mon
   ```
   Crea `captura-01.cap` (o `.pcapng` según versión) [V: `-w` y `--bssid` en docs]. Evita `--ivs`: solo guarda IVs y no sirve para handshakes [V].

5. **Forzar reconexión (solo si el alcance lo permite).** Qué hace: deauth de un cliente para que reconecte y se capture el 4-way handshake; la nota "WPA handshake: <BSSID>" en airodump confirma la captura [V].
   ```bash
   sudo aireplay-ng --deauth 4 -a <BSSID> -c <CLIENTE> wlan0mon
   ```
   Empieza con pocos paquetes. Si la red tiene PMF/802.11w obligatorio (WPA3 o WPA2 con PMF), el deauth no funciona como se espera [V, Vanhoef: PMF obligatorio en WPA3]. Antes, opcional: `sudo aireplay-ng --test wlan0mon` para comprobar inyección [V].

6. **Verificar que hay handshake o PMKID.**
   ```bash
   aircrack-ng captura-01.cap
   ```
   Si no hay handshake, aircrack-ng informa "No valid WPA handshakes found" y hay que recapturar [V, docs cracking_wpa]. Con hcxtools puedes ver el resumen de la conversión en el paso 8 [NP en el detalle de salida].

7. **Crackeo directo con aircrack-ng (CPU, diccionario).** Qué hace: prueba cada palabra de la lista contra el MIC del handshake; la contraseña debe estar en el diccionario [V, docs].
   ```bash
   aircrack-ng -w <diccionario> -b <BSSID> captura-01.cap
   ```
   Un diccionario de prueba viene en el código fuente de aircrack-ng (directorio `test`) [V, docs]. `rockyou.txt` es el diccionario habitual en Kali [NP en este entorno; ruta típica `/usr/share/wordlists/`].

8. **Convertir a formato hashcat 22000 (recomendado).** Qué hace: extrae PMKID y pares EAPOL a un único archivo de hash.
   ```bash
   hcxpcapngtool -o captura.hc22000 captura-01.pcapng
   ```
   El wiki de hashcat indica `hcxpcapngtool -o hash.hc22000 dumpfile.pcapng`; no uses wpaclean, filtros de captura ni combines varios `.pcapng` [V, hashcat wiki]. Si el archivo es `.cap`, la conversión directa con hcxpcapngtool no está confirmada [NP: prueba y compara con `aircrack-ng`].

9. **Captura PMKID sin cliente (alternativa, solo con autorización).** Qué hace: pide el PMKID al AP sin esperar a un cliente.
   ```bash
   sudo hcxdumptool -i wlan0mon -o pmkid.pcapng --enable_status=1
   hcxpcapngtool -o pmkid.hc22000 pmkid.pcapng
   ```
   Los flags de `hcxdumptool` son [NP]; confirma con `hcxdumptool -h` en tu versión, porque la documentación consultada no los detalla. Revisa siempre la BPF/filtro de AP para no capturar fuera del alcance (el README lo exige si el entorno no está controlado) [V].

10. **Crackeo offline con hashcat (GPU).**
    ```bash
    hashcat -m 22000 captura.hc22000 <diccionario>
    hashcat -m 22000 captura.hc22000 <diccionario> -r rules/best64.rule
    hashcat -m 22000 captura.hc22000 --show
    ```
    El primer comando es el ataque de diccionario documentado en el wiki de hashcat [V]. La regla `best64.rule` viene con hashcat [NP: verifica la ruta en tu instalación]. `--show` muestra las claves ya recuperadas [NP: documentado en hashcat, no ejecutado].

11. **Modos antiguos.** Los modos 2500 y 16800 están deprecados y bloqueados por plugins; usa 22000 (WPA-PBKDF2-PMKID+EAPOL) y 22001 (si ya tienes la PMK) [V, foro hashcat]. Si un reto solo da un `.hccapx` antiguo, el wiki indica que `.hccapx` no se puede convertir [V].

Ruta B — Bluetooth Low Energy (BLE).

12. **Descubrir y enumerar con bettercap (Linux).** Qué hace: escanea dispositivos BLE cercanos y lista servicios y características.
    ```bash
    sudo bettercap -iface hci0
    ble.recon on
    ble.show
    ble.enum <MAC_BLE>
    ```
    Los comandos `ble.recon`, `ble.show` y `ble.enum` aparecen en walkthroughs de terceros [NP: verifica con `help` dentro de bettercap].

13. **Interacción con características (gatttool, deprecado).** Qué hace: lee y escribe en handles para probar acceso sin autenticación.
    ```bash
    gatttool -b <MAC_BLE> -I
    ```
    Dentro: `connect`, `characteristics`, `char-read-hnd <handle>`, `char-write-req <handle> <valor_hex>` [NP]. Anota qué escrituras aceptan sin pareado.

14. **Sniffing de emparejamiento (solo con Ubertooth u otro sniffer).** Qué hace: captura el intercambio de emparejamiento para intentar recuperar la clave temporal (TK) del emparejamiento legacy.
    ```bash
    ubertooth-btle -f -o ble.pcap
    crackle -i ble.pcap -o ble_decrypted.pcap
    ```
    Los flags son [NP: confirma en `ubertooth-btle --help` y en la página de manual]. Solo el emparejamiento "Just Works"/passkey legacy es vulnerable a este crackeo; LE Secure Connections no [NP: revisar la especificación antes de depender de ello].

Ruta C — RF genérico (ISM).

15. **Escanear la banda y decodificar con rtl_433.** Qué hace: decodifica protocolos ISM conocidos (sensores, mandos, timbres) a JSON.
    ```bash
    rtl_433 -f 433.92M
    rtl_433 -f 433.92M -F json -M time:iso
    rtl_433 -a
    rtl_433 -A
    ```
    `-f` fija la frecuencia (433.92 MHz por defecto), `-a` analiza la señal como texto y `-A` resume pulsos y periodos; `-p` corrige el error de frecuencia del tuner [V, manual rtl_433]. Los flags `-F json` y `-M time:iso` son [NP: confirma en `rtl_433 -h`].

16. **Grabación IQ y análisis manual.** Qué hace: guarda la señal para demodularla fuera de rtl_433.
    ```bash
    rtl_sdr -f 433920000 -s 2000000 -g 40 captura.cu8
    ```
    Formatos y flags de `rtl_sdr` [NP]. Analiza con inspectrum (Linux) o GNU Radio: identifica OOK/FSK, anchos de pulso y preámbulo.

Ruta D — NFC/RFID (MIFARE Classic).

17. **Identificar la tarjeta.** Qué hace: determina tipo y UID.
    ```bash
    nfc-list
    ```
    Con Proxmark3 (cliente Iceman) [V cheatsheet para la sintaxis `hf mf`; comandos exactos NP]:
    ```text
    hf 14a info
    ```

18. **Recuperar claves por ataque nested (mfoc).** Qué hace: si conoces al menos una clave de sector, recupera las demás.
    ```bash
    mfoc -O tarjeta.mfd
    ```
    El nombre de los flags viene de la página de Kali (`-k`, `-f`, `-P`, `-O`) [V paquete Kali; uso exacto NP]. Si mfoc reporta que la tarjeta no es vulnerable, prueba `mfoc-hardnested` [NP, según guía de hardnested].

19. **Con Proxmark3 (equivalente).** Qué hace: ataque nested con una clave conocida, o hardnested si no es vulnerable.
    ```text
    hf mf nested --1k
    hf mf hardnested --1k
    ```
    El ataque `nested` requiere una clave conocida y `--1k` marca MIFARE Classic 1k [V: cheatsheet y guía de terceros; comandos a confirmar con `hf mf -h`].

20. **Volcado y lectura.** Con las claves recuperadas, vuelca los sectores y busca la bandera en bloques de datos (no en bloques de trailer). Guarda el `.mfd` original.

21. **Registro final.** Anota en `ctf/<reto>/wireless/` la ruta usada, el BSSID/MAC/UID, los archivos generados, los diccionarios y el resultado de cada comando.

Propuesta pendiente de aprobación: si la captura en vivo se hace siempre en una VM Kali con USB, o si se permite Windows nativo para la fase de captura.

## Qué buscar (indicadores de vulnerabilidad)
- **Wi-Fi WPA2-PSK sin PMF:** el handshake se puede forzar con deauth y el crackeo es offline; PMKID disponible sin cliente. Es el caso más habitual en retos [V, docs aircrack-ng y hashcat].
- **Contraseña en diccionario:** PSK débil (palabras comunes, nombres de red, fechas) fácil de encontrar en rockyou o en diccionarios personalizados; el crackeo funciona solo si la clave está en la lista [V, docs aircrack-ng].
- **WPA3 o transición WPA2/WPA3:** en WPA3-only, PMF es obligatorio y el deauth no sirve; en modo transición se puede forzar downgrade a WPA2 y crackear por diccionario. Las fugas laterales de SAE (Dragonblood) permiten ataques offline en implementaciones afectadas [V, Vanhoef et al., papers.mathyvanhoef.com]. El modo 22000 de hashcat cubre WPA2-PSK; SAE necesita otro enfoque [NP: no investigado en detalle].
- **Redes abiertas o WEP:** sin cifrado o con WEP, el análisis es de tramas y de IVs (la captura de IVs es el ataque clásico de WEP) [NP: no investigado en esta sesión; ver aircrack-ng para WEP].
- **BLE sin autenticación:** características escribibles o legibles sin pareado; servicios personalizados con valores en claro [NP: práctica habitual en los walkthroughs de BLE].
- **BLE con pareado legacy (Just Works o passkey):** la TK es recuperable con sniffing del emparejamiento si la clave es débil [NP: confirmar con la especificación].
- **RF en 433/868 MHz sin cifrado o con código fijo:** señales repetibles (rolling code ausente) decodificables con rtl_433; un código fijo permite reproducción [NP].
- **MIFARE Classic:** claves por defecto (p. ej. `FFFFFFFFFFFF`) y ataques nested con PRNG predecible; tarjetas que resisten nested sugieren hardnested [V: guía de hardnested y cheatsheet Proxmark3]. Algunas tarjetas más nuevas (MIFARE Classic EV1) generan nonces aleatorios y frenan el nested [V, fuente de terceros con referencia a eprint].
- **Pistas en el enunciado:** nombre de red, fabricante, modelo de mando o sensor, o un diccionario entregado.

## Cómo interpretar y pasar a explotación
- Una captura con `WPA handshake` o un PMKID es el resultado intermedio; la clave recuperada es un hecho solo cuando el crackeo devuelve la clave y puedes conectarte o verificarla con `hashcat --show` [V].
- Una clave de Wi-Fi recuperada permite descifrar tráfico de esa red con la clave del reto: usa `airdecap-ng` (aircrack-ng) para descifrar un `.cap` con ESSID y clave conocidos [NP: no verificado en esta sesión].
- Una clave BLE o una característica escribible llevan a la fase de dispositivo o de firmware (plan de análisis de hardware/rev si existe).
- Una clave MIFARE o un volcado `.mfd` pasa al análisis de sectores y a buscar la bandera en datos, no en trailers.
- Un mensaje en RF decodificado (JSON o bits) puede ser la bandera directamente o requerir decodificación posterior (cripto o codificación): cruza con el plan de criptografía (**03-criptografia.md** si existe) [NP: nombre de plan a confirmar].
- Antes de cualquier inyección (deauth, reinyección, escritura en BLE, escritura en tarjeta), confirma el objetivo en `ctf/SCOPE.md` y que la fase activa está autorizada en el enunciado.

## Errores comunes y trampas
- **Usar Windows nativo para captura de monitor:** la mayoría de fallos vienen de ahí. Usa Kali en VM con USB o un adaptador verificado.
- **Adaptador sin inyección:** `aireplay-ng --test` debe pasar antes de cualquier deauth; un chipset Intel/Broadcom/Qualcomm no es recomendable para inyección [V, README hcxdumptool].
- **Capturas dañadas o filtradas:** no uses wpaclean ni filtros de captura antes de hcxpcapngtool; no combines `.pcapng` [V, hashcat wiki].
- **Diccionario sin la clave:** aircrack-ng y hashcat solo prueban lo que contiene la lista; no implica que la red sea segura ni que el crackeo haya fallado en la herramienta.
- **Deauth ineficaz:** con PMF o WPA3 obligatorio, el cliente no reconecta como se espera; no insistas con más paquetes.
- **Confundir modos de hashcat:** 16800 y 2500 están deprecados; usa 22000 [V].
- **Comandos desactualizados:** la sintaxis de aircrack-ng, hcxdumptool y bettercap cambia entre versiones; confirma con `-h` o con `man`.
- **Canal equivocado:** airodump sin `-c` puede saltar de canal y perder el handshake; fija canal y BSSID.
- **Captura fuera de alcance:** hcxdumptool y airodump capturan todo lo que ven; usa filtros de AP y guarda solo lo del alcance.
- **BLE sin hardware adecuado:** el sniffing de emparejamiento requiere sniffer específico (Ubertooth, Sniffle); Bluetooth estándar no lo permite [NP].
- **Gatttool deprecado:** funciona, pero bettercap o bluetoothctl pueden ser más estables según la versión de BlueZ [NP].

## Fuentes
- aircrack-ng — Cracking WPA/WPA2 (wiki oficial) — https://www.aircrack-ng.org/doku.php?id=cracking_wpa [V, consultada]
- aircrack-ng — airodump-ng (wiki oficial) — https://www.aircrack-ng.org/doku.php?id=airodump-ng [V, consultada]
- aircrack-ng — aireplay-ng (wiki oficial) — https://www.aircrack-ng.org/doku.php?id=aireplay-ng [V, consultada]
- aircrack-ng — Kali Linux tool page — https://www.kali.org/tools/aircrack-ng/ [solo en búsqueda]
- hashcat wiki — WPA/WPA2 (modo 22000 y formato) — https://hashcat.net/wiki/cracking_wpawpa2 [V, consultada]
- hashcat forum — Deprecación de modos 2500/2501 y 16800/16801 — https://hashcat.net/forum/thread-10253.html [V, consultada]
- hcxdumptool (ZerBea) — README — https://github.com/ZerBea/hcxdumptool [V, consultada]
- hcxtools (ZerBea) — repositorio — https://github.com/ZerBea/hcxtools [solo en búsqueda]
- Vanhoef et al. — Dragonblood (paper, IEEE S&P 2020) — https://papers.mathyvanhoef.com/dragonblood.pdf [solo en búsqueda; no leído]
- Vanhoef — Black Hat USA 2019, Dragonblood whitepaper — https://i.blackhat.com/USA-19/Wednesday/us-19-Vanhoef-Dragonblood-Attacking-The-Dragonfly-Handshake-Of-WPA3-wp.pdf [solo en búsqueda]
- Wireshark wiki — WLAN capture setup — https://wiki.wireshark.org/CaptureSetup/WLAN [solo en búsqueda; fragmento citado]
- SecWiki — Npcap/WiFi adapters — https://secwiki.org/w/Npcap/WiFi_adapters [solo en búsqueda]
- HackTricks — Pentesting Wifi — https://book.hacktricks.xyz/generic-methodologies-and-resources/pentesting-wifi [página oficial devolvió solo navegación; contenido de espejos, no verificado]
- HackTricks — Pentesting BLE — https://book.hacktricks.xyz/todo/radio-hacking/pentesting-ble-bluetooth-low-energy [solo en búsqueda]
- HardwareAllTheThings — Bluetooth — https://swisskyrepo.github.io/HardwareAllTheThings/protocols/bluetooth [solo en búsqueda]
- ubertooth-btle (man page) — https://www.mankier.com/1/ubertooth-btle [solo en búsqueda]
- rtl_433 — manual (man page Arch) — https://man.archlinux.org/man/rtl_433.1.en [solo en búsqueda]
- rtl_433 — docs/OPERATION.md — https://github.com/merbanan/rtl_433/blob/master/docs/OPERATION.md [solo en búsqueda]
- HardwareAllTheThings — MIFARE Classic — https://swisskyrepo.github.io/HardwareAllTheThings/protocols/rfid-nfc/hf-mifare-classic [solo en búsqueda]
- Proxmark3 (RfidResearchGroup) — cheatsheet — https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/cheatsheet.md [solo en búsqueda]
- hardnested (bennesp) — https://github.com/bennesp/hardnested [solo en búsqueda]
- mfoc — Kali Linux tool page — https://www.kali.org/tools/mfoc [solo en búsqueda]
- Microsoft Learn — USB/WSL (usbipd) — https://learn.microsoft.com/en-us/windows/wsl/usbip [404 al consultar; no válida]

## Relación con otros planes
- `07-osint-reconocimiento.md`: identificar la red, el fabricante o el dispositivo a partir de metadatos o nombres públicos (SSID, OUI de la MAC).
- `02-red-conexiones.md`: una vez recuperada la clave Wi-Fi, el tráfico descifrado pasa al análisis de red.
- `05-bases-datos-consultas.md` y planes de aplicaciones web: si la clave o el dispositivo expone un panel o API.
- Planes de forense y criptografía (si existen en `analisis/`): para tramas descifradas, decodificación de mensajes RF o claves de sector. Pendiente de confirmar nombres de archivo.
- Planes de hardware/firmware (si existen): para dispositivos BLE o RF que requieren extraer firmware.

## Autorización
- Este documento es metodología de la biblioteca `analisis/`. No investiga ningún objetivo concreto.
- Ningún paso se aplica a un objetivo real sin que figure en un `ctf/SCOPE.md` confirmado. A fecha de esta redacción, ese archivo no existe en el repositorio.
- La captura en vivo, el deauth, la inyección y la escritura en dispositivos o tarjetas son fases activas: solo contra redes y dispositivos del alcance del reto, y solo cuando el enunciado lo permita.
- Todas las recomendaciones de este plan (VM Kali, uso de Windows nativo, decisiones de alcance) son propuestas pendientes de aprobación.
