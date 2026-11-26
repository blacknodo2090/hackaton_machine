# Plan de análisis 03 — Puertos y servicios

- **Punto de vista:** enumeración a fondo de cada servicio detectado tras el escaneo: banner, versión, configuración, acceso anónimo o con credenciales por defecto, y mapeo versión→CVE para decidir si pasar a explotación.
- **Cuándo aplicarlo:** después del escaneo de puertos (plan 02) y antes de cualquier explotación. Se aplica a cada puerto abierto con servicio identificado, y también a puertos "raros" o de servicio desconocido.

## Preparación

- **Autorización:** el objetivo debe figurar en `ctf/SCOPE.md` confirmado antes de ejecutar cualquier comando contra él. Este plan es solo metodología y no cubre un objetivo concreto.
- **Inventario previo:** lista de puertos abiertos TCP y UDP con `nmap` (salida `-oA`), guardada en una carpeta de evidencias por objetivo (por ejemplo `scans/`).
- **Ritmo:** fijar límites de conexiones y reintentos. Los servicios de autenticación (FTP, SSH, SMB, RDP, WinRM) pueden bloquear cuentas con fuerza bruta. Antes de probar contraseñas, confirmar que el reto lo permite.
- **Registro:** guardar cada comando, su salida y la hora. Los banners y las respuestas de enumeración son la evidencia del informe.
- **Entorno:** Windows nativo para comprobaciones simples (`Test-NetConnection`, `curl.exe`, `ssh`, `ftp`). Kali o WSL para `smbclient`, `rpcclient`, `snmpwalk`, `onesixtyone`, `enum4linux-ng` y NetExec. Los escaneos SYN de `nmap` requieren privilegios y Npcap en Windows; sin ellos, usar `-sT`.

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| `nmap -sV` y `--version-intensity` | Detecta versión y producto por probes. Con `-sV` se ejecutan automáticamente los scripts de categoría `version`. | Windows con instalador oficial y Npcap para SYN; `-sT` sin privilegios. Kali/WSL para todo. |
| `nmap --script` (NSE) | Scripts por servicio (ftp-anon, smb-*, snmp-*, smtp-commands, dns-zone-transfer, ssh2-enum-algos, rdp-*). Índice oficial en nsedoc. | Igual que nmap. |
| `ncat` / `nc` (netcat) | Captura de banners y conversación manual con texto (SMTP, FTP, HTTP, SSH). | `ncat` viene con nmap en Windows; `nc` en Kali/WSL. |
| `Test-NetConnection` | Comprobar si un puerto TCP responde. | Nativo Windows (PowerShell). |
| `curl` | HTTP(S), WinRM (`/wsman`), FTP (`ftp://`) con credenciales. | Nativo (`curl.exe`) y Kali/WSL. |
| `ssh` (cliente OpenSSH) | Ver métodos de autenticación (`-v`), banner y algoritmos. | Nativo Windows (OpenSSH) y Kali/WSL. |
| `ftp` (cliente) | Prueba manual de acceso anónimo. | Nativo Windows (`ftp.exe`) y Kali/WSL. |
| `enum4linux-ng` | Enumeración SMB/RPC integrada: usuarios, grupos, shares, política de contraseñas, con salida JSON/YAML (`-oJ`, `-oY`). Requiere herramientas Samba. | Kali/WSL (recomendado). En Windows, solo con Python y dependencias Samba, poco práctico. |
| `smbclient` | Listar shares (`-L`), acceso anónimo (`-N`), descargas. | Kali/WSL. No nativo en Windows. |
| `rpcclient` | Consultas RPC: `enumdomusers`, `querydominfo`, `enumdomgroups`, sesión nula. | Kali/WSL. |
| `nbtscan` | Escaneo NetBIOS (137/udp). | Kali/WSL. |
| `dig` | Versión (`version.bind`), transferencias de zona AXFR. | Kali/WSL. En Windows, `nslookup` sirve para consultas básicas (no verificado para AXFR). |
| `snmpwalk` (net-snmp) | Recorrer el árbol MIB con una comunidad válida. | Kali/WSL; net-snmp tiene binarios para Windows (no verificado en esta sesión). |
| `onesixtyone` | Fuerza bruta de cadenas de comunidad SNMP (`-c`, `-i` para varios hosts). | Kali/WSL. |
| NetExec (`nxc`) | Autenticación y enumeración multiprotocolo: smb, winrm, rdp, ssh, ftp, ldap, mssql, vnc, nfs, wmi. Sucesor de CrackMapExec. | Kali/WSL (recomendado). |
| `hydra` | Fuerza bruta de credenciales por servicio (con cuidado de bloqueos). | Kali/WSL. |
| `searchsploit` (exploitdb) | Buscar exploits públicos por producto y versión, offline. | Kali/WSL. |
| `braa` | Fuerza bruta de OIDs SNMP cuando ya hay comunidad (según HackTricks, no verificado en esta sesión). | Kali/WSL. |

> **Catálogo Kali:** ver [KALI_CATALOG.md](../docs/tools/KALI_CATALOG.md) → Reconnaissance · Discovery.

## Procedimiento paso a paso

1. **Confirmar el alcance.** Leer `ctf/SCOPE.md` y anotar qué IP y puertos están autorizados.

2. **Ampliar el inventario de puertos.**
   ```bash
   nmap -Pn -p- --min-rate 2000 -oA scans/full <IP>
   ```
   Sirve para encontrar puertos fuera de los habituales. Qué hace: escanea todos los puertos TCP con velocidad alta.

3. **Versión y scripts por defecto sobre los puertos encontrados.**
   ```bash
   nmap -Pn -sV -sC -p <lista_puertos> -oA scans/svc <IP>
   ```
   `-sV` detecta versiones y ejecuta los scripts de versión; `-sC` ejecuta la categoría `default`. Nota: `-sC` solo no ejecuta los scripts de versión, por eso se usan juntos (fuente: [nmap.org/book/nse-vscan](https://nmap.org/book/nse-vscan.html)).

4. **Servicios UDP relevantes.**
   ```bash
   sudo nmap -sU --top-ports 100 -sV -Pn <IP>
   ```
   Qué hace: busca SNMP (161), DNS (53) y NetBIOS (137), que un escaneo TCP no muestra. Es lento; limitar a `--top-ports` o a puertos concretos.

5. **Captura de banners manual** (cuando nmap no identifica bien el servicio).
   ```bash
   nc -nv -w 3 <IP> <puerto>
   ```
   Qué hace: conecta, muestra el banner y permite escribir comandos a mano. En Windows, `ncat -nv <IP> <puerto>`.

6. **FTP (21).**
   ```bash
   nmap -Pn -p21 -sV --script ftp-anon,ftp-syst <IP>
   curl -v ftp://<IP>/ --user anonymous:anonymous
   ```
   Qué hace: comprueba acceso anónimo y tipo de servidor. Si hay listado, revisar escritura y ficheros sensibles. Para la versión, comparar el banner con CVE (ver sección de interpretación). Revisar si el banner es `vsFTPd 2.3.4` (ver indicadores).

7. **SSH (22).**
   ```bash
   ssh -v -o BatchMode=yes -o PreferredAuthentications=none usuario@<IP>
   nmap -Pn -p22 -sV --script ssh2-enum-algos <IP>
   ```
   Qué hace: el primer comando muestra los métodos de autenticación aceptados sin intentar contraseñas. El segundo lista algoritmos (script citado en fuente de terceros; verificar en `nmap --script-help ssh2-enum-algos`).

8. **SMB / NetBIOS (139, 445).**
   ```bash
   nmap -Pn -p139,445 --script smb-protocols,smb2-security-mode,smb-os-discovery,smb-vuln-ms17-010 <IP>
   smbclient -L //<IP> -N
   smbclient //<IP>/<recurso> -N
   rpcclient -U "" -N <IP> -c "enumdomusers"
   rpcclient -U "" -N <IP> -c "querydominfo"
   enum4linux-ng -A -oJ scans/enum4linux <IP>
   nbtscan -r <red>/24
   ```
   Qué hace:
   - `smb-protocols` y `smb2-security-mode` muestran versiones de SMB y si la firma es obligatoria.
   - `smb-vuln-ms17-010` comprueba si SMBv1 es vulnerable a MS17-010 (CVE-2017-0143, EternalBlue) (fuente: [nmap smb-vuln-ms17-010](https://nmap.org/nsedoc/scripts/smb-vuln-ms17-010.html)).
   - `smbclient -L -N` lista shares con sesión nula.
   - `rpcclient` con `-N` prueba sesión anónima para usuarios y dominio.
   - `enum4linux-ng -A` ejecuta todas las comprobaciones simples. Las opciones están en [su README](https://github.com/cddmp/enum4linux-ng).
   - `nbtscan` identifica nombres NetBIOS. Comando tomado de HackTricks.
   Si hay credenciales de invitado (guest), probar `-U guest` con contraseña vacía.

9. **SNMP (161/udp).**
   ```bash
   sudo nmap -sU -p161 --script "snmp* and not snmp-brute" <IP>
   onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings-onesixtyone.txt <IP>
   snmpwalk -v2c -c public <IP>
   snmpwalk -v1 -c public <IP> 1.3.6.1.2.1.25.4.2.1.2
   ```
   Qué hace:
   - El primer comando lee datos sin fuerza bruta.
   - `onesixtyone` prueba cadenas comunes. Con SNMPv1/v2c, una comunidad errónea no responde, así que una respuesta indica cadena válida (fuente: [HackTricks SNMP](https://book.hacktricks.xyz/network-services-pentesting/pentesting-snmp)).
   - `snmpwalk` recorre el árbol. El OID `1.3.6.1.2.1.25.4.2.1.2` lista procesos en ejecución (OID estándar; no verificado en esta sesión contra la MIB oficial).
   Probar también `private` (escritura, riesgo) solo si el alcance lo permite.

10. **SMTP (25, 465, 587).**
    ```bash
    nc -nv <IP> 25
    # tras el banner:
    EHLO prueba
    VRFY root
    nmap -Pn -p25 --script smtp-commands,smtp-enum-users <IP>
    ```
    Qué hace: revela extensiones (`smtp-commands`) y permite validar usuarios con VRFY/EXPN/RCPT. `smtp-enum-users` se cita de memoria (verificar en nsedoc).

11. **DNS (53).**
    ```bash
    dig @<IP> version.bind chaos txt
    dig @<IP> <dominio> AXFR
    nmap -Pn -p53 --script dns-zone-transfer --script-args dns-zone-transfer.domain=<dominio> <IP>
    ```
    Qué hace: el primero obtiene la versión del servidor; los dos siguientes piden transferencia de zona. `dns-zone-transfer` está en categoría intrusiva según nsedoc (fuente: [nmap nsedoc](https://nmap.org/nsedoc/scripts/)). Solo tiene sentido si el alcance incluye ese DNS.

12. **HTTP/HTTPS (80, 443, 8080, 8443).** Este plan no cubre la enumeración web en profundidad (no existe aún un plan de web en `analisis/`).
    ```bash
    curl -sI http://<IP>:<puerto>/
    nmap -Pn -p<puertos> --script http-title,http-headers,http-methods,ssl-cert <IP>
    ```
    Qué hace: cabeceras, métodos permitidos y certificado. Dejar la fase web a su plan propio.

13. **RDP (3389).**
    ```powershell
    Test-NetConnection -ComputerName <IP> -Port 3389
    ```
    ```bash
    nmap -Pn -p3389 --script rdp-enum-encryption,rdp-ntlm-info <IP>
    ```
    Qué hace: comprueba si hay NLA y el nivel de cifrado; `rdp-ntlm-info` revela el nombre NetBIOS/dominio (cita de guía de terceros, verificar en nsedoc).

14. **WinRM (5985, 5986).**
    ```bash
    curl -i http://<IP>:5985/wsman
    nxc winrm <IP> -u <usuario> -p <contraseña>
    ```
    Qué hace: una respuesta 401 con `WWW-Authenticate: Negotiate` confirma el servicio (comprobación de elaboración propia, no verificada en fuente). NetExec admite winrm como protocolo (fuente: [mirror de docs NetExec](https://tldrbins.github.io/nxc)).

15. **Bases de datos y otros (1433, 3306, 5432, 6379, 27017, 1521, 2049).** Comprobar primero el banner y la autenticación. El detalle está en el plan 05. Para NFS (2049), `showmount -e <IP>` (no verificado en esta sesión).

16. **Credenciales por defecto y anónimas.** Probar solo después de los pasos anteriores, con listas acotadas.
    ```bash
    nxc smb <IP> -u '' -p '' --shares
    nxc smb <IP> -u 'guest' -p '' --shares
    hydra -L users.txt -P pass.txt ssh://<IP> -t 4
    ```
    Qué hace: sesión nula y de invitado, y fuerza bruta limitada. Revisar primero la documentación del fabricante para contraseñas por defecto.

17. **Registrar resultados.** Para cada puerto: servicio, versión, método de acceso, evidencia (comando y salida) y CVE candidatos.

## Qué buscar (indicadores de vulnerabilidad)

- **FTP:** login anónimo con listado o escritura; banner `vsFTPd 2.3.4`. La versión 2.3.4 contiene una puerta trasera que abre una shell en el puerto 6200/tcp (CVE-2011-2523). Las fuentes difieren en la severidad: NVD da 9.8 y Red Hat da 8.1 (ver [NVD/Red Hat/Debian](https://security-tracker.debian.org/tracker/CVE-2011-2523), [aviso oss-security](https://www.openwall.com/lists/oss-security/2011/07/11/5)).
- **SMB:** SMBv1 activo; respuesta `STATUS_INSUFF_SERVER_RESOURCES` del script ms17-010 (indicio de no parcheado, según el script); sesión nula que lista shares o usuarios; firma SMB no obligatoria; versión de Samba entre 3.0.0 y 3.0.25rc3 con `username map script` activo (CVE-2007-2447). Ese CVE afecta a configuraciones con scripts externos definidos en `smb.conf` y no está activo por defecto (fuente: [aviso Samba](https://www.samba.org/samba/security/CVE-2007-2447.html); [CERT](https://kb.cert.org/vuls/id/268336)).
- **SNMP:** comunidades `public` o `private`; cadena `private` con escritura; datos de procesos, usuarios o interfaces accesibles.
- **SSH:** autenticación por contraseña habilitada junto con usuarios conocidos; algoritmos antiguos (verificar contra recomendaciones del fabricante).
- **SMTP:** VRFY/EXPN activos (enumeración de usuarios); relé abierto (no verificado en esta sesión, sin fuente).
- **DNS:** transferencia AXFR permitida; `version.bind` con versión detallada.
- **RDP:** sin NLA; cifrado débil; nombre de dominio expuesto.
- **WinRM:** accesible desde la red con credenciales reutilizadas de otro servicio.
- **Bases de datos:** sin autenticación (Redis, MongoDB, MySQL con usuario vacío). Detalle en plan 05.
- **Transversal:** la misma credencial funciona en varios servicios; un banner antiguo en un servicio que se ejecuta en un sistema operativo también antiguo.

## Cómo interpretar y pasar a explotación

1. **Del banner al CVE.** Usar la versión exacta que da nmap (`-sV`) y buscarla en la base de vulnerabilidades (NVD, distribuciones) y en `searchsploit`. Tratar la coincidencia solo como candidato.
2. **Confirmar antes de explotar.** Comprobar la versión con una prueba no destructiva (un script NSE de comprobación o el banner). Las distribuciones aplican parches sin cambiar la versión visible: en el caso de vsftpd, Red Hat marca EL8 como "no afectado" (fuente: [Red Hat CVE-2011-2523](https://access.redhat.com/security/cve/cve-2011-2523)).
3. **Priorizar.** Primero acceso sin autenticación (anónimo, sesión nula, comunidad SNMP, puerta trasera), luego credenciales reutilizadas, después CVE con exploit público, y por último fuerza bruta.
4. **Documentar el acceso.** Cada paso con comando, salida y hora. Apuntar qué datos se obtienen (usuarios, shares, contraseñas en texto claro) para alimentar otros servicios.
5. **Pasar a explotación.** Elegir el exploit, verificar que el alcance lo cubre y ejecutarlo en una sola acción. La explotación de cada servicio no está en este plan; ver los planes de explotación cuando existan.

Qué no hacer sin aprobación: escritura en SNMP (`private`), transferencias de zona en servidores que no estén en alcance, o cualquier exploit que pueda tumbar el servicio.

## Errores comunes y trampas

- **Escanear solo TCP.** SNMP, DNS y NetBIOS están en UDP y se pierden. Hacer al menos un escaneo UDP de los puertos comunes.
- **Creer el banner.** Los banners se pueden modificar, y las distribuciones hacen backports. Confirmar con otra evidencia.
- **Usar `-sC` sin `-sV`.** Los scripts de versión no se ejecutan (ver paso 3).
- **Confundir sesión nula con invitado.** `smbclient -N` y `-U guest` dan resultados distintos; probar ambos.
- **Fuerza bruta sin control.** Bloqueos de cuenta y ruido. Limitar hilos y revisar la política de contraseñas (`enum4linux-ng -P`) antes.
- **Dar por fiable un script de detección.** El script ms17-010 hace una comprobación que puede no ser concluyente; confirmar con el servicio real.
- **Escanear fuera del alcance.** Revisar `ctf/SCOPE.md` antes de cada subred y de cada ejecución de `nbtscan -r`.
- **En Windows, faltan herramientas Samba.** `smbclient`, `rpcclient` y `enum4linux-ng` requieren Kali o WSL.
- **Filtros de cortafuegos.** Un puerto filtrado no está cerrado; probar otros tipos de escaneo o desde otra ruta.
- **Fase web fuera de este plan.** No intentar la enumeración web profunda desde aquí.

## Fuentes

**Verificadas (consultadas en esta sesión):**
- [nmap — Version Detection Using NSE](https://nmap.org/book/nse-vscan.html)
- [nmap — Índice de scripts NSE (nsedoc)](https://nmap.org/nsedoc/scripts/)
- [nmap — smb-vuln-ms17-010](https://nmap.org/nsedoc/scripts/smb-vuln-ms17-010.html)
- [enum4linux-ng (cddmp) — README con opciones](https://github.com/cddmp/enum4linux-ng)
- [Debian Security Tracker — CVE-2011-2523](https://security-tracker.debian.org/tracker/CVE-2011-2523)
- [Red Hat — CVE-2011-2523](https://access.redhat.com/security/cve/cve-2011-2523)
- [oss-security, aviso vsftpd 2.3.4 (2011-07-11)](https://www.openwall.com/lists/oss-security/2011/07/11/5)
- [Samba — CVE-2007-2447](https://www.samba.org/samba/security/CVE-2007-2447.html)
- [CERT/CC — VU#268336](https://kb.cert.org/vuls/id/268336)
- [HackTricks — Pentesting SNMP (resultados de búsqueda; página live no abierta)](https://book.hacktricks.xyz/network-services-pentesting/pentesting-snmp)
- [HackTricks — Pentesting SMB (contenido parcial vía búsqueda; página live redirigida y no abierta)](https://book.hacktricks.xyz/network-services-pentesting/pentesting-smb)
- [NetExec — lista de protocolos (mirror secundario)](https://tldrbins.github.io/nxc)

**No verificadas o solo de terceros:**
- NVD CVE-2011-2523 ([nvd.nist.gov](https://nvd.nist.gov/vuln/detail/CVE-2011-2523)): la página devolvió solo el título; las cifras de severidad se toman de Red Hat y Wiz/Debian.
- Repositorio oficial de NetExec (pennyw0rth/netexec): no se abrió.
- `rdp-ntlm-info`, `ssh2-enum-algos`, `smtp-enum-users`, `ftp-anon` (este último sí aparece en la búsqueda, pero con descripción de terceros): no se encontró página nsedoc en esta sesión; verificar con `nmap --script-help <nombre>`.
- Guía HackTricks de SMB en su versión oficial (hacktricks.wiki redirige y no se pudo abrir); se usó contenido de búsqueda.

## Relación con otros planes

- **Plan 02 — Red y conexiones:** provee la lista de hosts y puertos que este plan enumera.
- **Plan 05 — Bases de datos y consultas:** detalle de los servicios de base de datos listados en el paso 15.
- **Plan 07 — OSINT y reconocimiento:** aporta nombres de dominio para DNS (paso 11) y nombres de usuario para SMTP, SMB y SSH.
- **Planes de web y de explotación:** no existen aún en `analisis/`. Este plan los referencia como destino de la fase siguiente.

## Autorización

- Este plan es metodología reutilizable. No investiga ningún objetivo concreto.
- Antes de ejecutar cualquier comando contra un host, confirmar en `ctf/SCOPE.md` confirmado que el host y el puerto están autorizados.
- Las acciones marcadas como de riesgo (escritura SNMP, fuerza bruta, transferencias AXFR, exploits con posible caída del servicio) requieren aprobación explícita del usuario.
- Las recomendaciones de este documento son propuestas pendientes de aprobación.
