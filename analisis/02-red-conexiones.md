# Plan de análisis 02 — Red y conexiones

- **Punto de vista:** examina la capa de red del objetivo: qué hosts responden, por qué rutas se llega a ellos, qué protocolos y puertos exponen, qué conexiones establece el sistema y si hay segmentos internos alcanzables solo desde un pivote. En CTF es la puerta de entrada a casi todos los retos de "red interna", "pivoting" y "hosts ocultos", y determina qué servicios se pueden atacar después.
- **Cuándo aplicarlo:** el reto entrega una IP, un host o un rango (p. ej. `10.10.10.5` o `10.10.10.0/24`), menciona una VPN, un "segundo adaptador", una DMZ o una red interna, o da una captura `.pcap` / un volcado de conexiones. También cuando el reconocimiento inicial no muestra nada útil en la IP principal.

## Preparación
- **Autorización:** confirmar que el objetivo figura en `ctf/SCOPE.md` confirmado antes de cualquier comando activo. Sin ello, solo se aplican los pasos pasivos sobre datos que el reto entrega (captura, volcado), sin tocar la red.
- **Acceso necesario:** para la fase activa, conectividad directa con el rango objetivo (VPN del CTF o máquina en la misma red). Para escaneos SYN, ARP y traceroute ICMP hacen falta privilegios de administrador/root.
- **Entorno:**
  - Windows nativo: PowerShell, `nmap` con Npcap instalado (el instalador de Nmap lo incluye), `tracert`, `arp`, `ipconfig`, `Get-NetTCPConnection`. Wireshark/tshark para captura.
  - Kali o WSL: `tcpdump`, `tshark`, `arp-scan`, `netdiscover`, `traceroute`, `ss`, `ligolo-ng`, `proxychains4`. En WSL2 el modo NAT limita el tráfico crudo; para escaneos activos es preferible una VM de Kali o el modo de red "mirrored" (supuesto, no verificado en fuente consultada).
- **Directorio de trabajo:** guardar salidas en una carpeta por objetivo (`resultados/<objetivo>/red/`) usando `-oA` de Nmap y `-w` de tcpdump, para no repetir escaneos.
- **Límites de ritmo:** en CTF compartido, usar `--min-rate` moderado y evitar escaneos repetidos que saturen la máquina del reto.

## Herramientas
| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| Nmap (+ NSE) | Descubrimiento de hosts (`-sn`), puertos, versiones, scripts y traceroute (`--traceroute`). | Windows: sí, requiere Npcap para escaneos crudos. Kali/WSL: sí, nativo. |
| arp-scan | Descubrimiento de hosts en la misma capa 2 mediante ARP; fiable en LAN. | Kali/WSL: sí. Windows: no lo verifiqué. |
| netdiscover | Descubrimiento ARP activo o pasivo en la red local. | Kali: sí. Windows: no. |
| tcpdump | Captura en línea de comandos y guardado en `.pcap`. | Kali/WSL: sí. Windows: no nativo (usar WinDump o Wireshark). |
| tshark / Wireshark | Análisis de capturas, filtros de captura (`-f`) y de visualización (`-Y`), estadísticas de conversaciones. | Ambos: sí (Wireshark instalable en Windows). |
| traceroute / tracert | Ruta hasta el host, saltos intermedios y redes no vistas. | Kali: `traceroute -n -I`. Windows: `tracert -d`. |
| ss / netstat | Conexiones y sockets abiertos del propio host o de un pivote. | Kali: `ss -tunap`. Windows: `netstat -ano`. |
| `Get-NetTCPConnection` | Conexiones TCP con filtros por estado y proceso propietario. | Windows: sí (PowerShell, módulo NetTCPIP). |
| ip / route / arp / ipconfig | Interfaces, rutas y tabla ARP/vecinos locales. | Kali: `ip addr`, `ip route`, `ip neigh`. Windows: `ipconfig /all`, `route print`, `arp -a`. |
| ligolo-ng | Pivoting con interfaz TUN: permite usar herramientas sin proxychains. | Kali: sí (`apt install ligolo-ng`). Windows: el agente puede compilarse; el proxy suele ir en Kali. |
| proxychains4 | Enrutar herramientas TCP por un proxy SOCKS a través de un pivote. | Kali/WSL: sí. Windows: no nativo. |
| chisel | Túneles TCP/SOCKS sobre HTTP cuando no hay TUN. | Multiplataforma (binario). |

## Procedimiento paso a paso
Orden: de lo pasivo a lo activo. Sustituir `10.10.10.0/24`, `eth0` y `10.10.10.5` por los valores del reto.

1. **Inventario local (si hay shell o acceso a la máquina).** Identifica interfaces, rutas y vecinos; un segundo adaptador o una ruta a otra subred es la señal de pivote.
   ```bash
   ip -br addr; ip route; ip neigh          # Linux
   ```
   ```powershell
   ipconfig /all; route print; arp -a        # Windows
   ```
   Qué hace: lista IPs, subredes alcanzables y hosts ya vistos por ARP.

2. **Conexiones activas y en escucha.** Busca servicios solo locales (127.0.0.1) y conexiones salientes a IPs internas.
   ```bash
   ss -tunap
   ```
   ```powershell
   Get-NetTCPConnection -State Listen,Established | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess
   ```
   Qué hace: muestra puertos escuchando y peers. Un puerto solo en 127.0.0.1 es candidato a túnel.

3. **Captura pasiva (si el reto da tráfico o se puede escuchar).** Guardar sin resolver nombres para no generar tráfico DNS extra.
   ```bash
   sudo tcpdump -i eth0 -nn -w red.pcap
   ```
   Qué hace: captura en bruto a archivo. Parar con Ctrl+C.

4. **Análisis de la captura.** Resumen de conversaciones y consultas DNS, que suelen revelar hosts y nombres internos.
   ```bash
   tshark -r red.pcap -q -z conv,ip
   tshark -r red.pcap -Y "dns.flags.response==0" -T fields -e ip.src -e dns.qry.name
   ```
   Qué hace: lista pares IP con tráfico y las consultas DNS hechas por cada origen.

5. **Hosts vivos por ARP (misma capa 2).** Es el método más fiable en LAN, porque muchos hosts no responden ICMP.
   ```bash
   sudo arp-scan -I eth0 10.10.10.0/24
   ```
   Qué hace: envía ARP a cada IP y reporta las que responden con MAC y fabricante.

6. **Descubrimiento de hosts con Nmap (sin escaneo de puertos).** Fuera de la LAN, ICMP y ARP no llegan, así que combinar sondas TCP/UDP.
   ```bash
   sudo nmap -sn -PE -PS22,80,443 -PA80,443 -PU53 10.10.10.0/24 -oA descubrimiento/ping
   ```
   Qué hace: ICMP echo, SYN a 22/80/443, ACK a 80/443 y UDP 53. Nota: cualquier opción `-P*` sustituye los valores por defecto de Nmap. Sin root, Nmap usa conexiones `connect` como alternativa.

7. **Ruta hacia los hosts vivos.** Confirma saltos y detecta redes intermedias no conocidas.
   ```bash
   sudo traceroute -n -I 10.10.10.5
   ```
   ```powershell
   tracert -d 10.10.10.5
   ```
   Qué hace: muestra cada salto. Un salto que aparece en un rango no visto antes indica una subred nueva. Nmap ofrece también `--traceroute` tras un escaneo.

8. **Puertos TCP en los hosts vivos.** Primero rápido, luego profundo.
   ```bash
   sudo nmap -Pn -sS -p- --min-rate 2000 10.10.10.5 -oA puertos/tcp-full
   sudo nmap -Pn -sS -sV -sC -p <puertos_abiertos> 10.10.10.5 -oA puertos/tcp-detalle
   ```
   Qué hace: el primero busca todos los puertos; el segundo añade versión (`-sV`) y scripts por defecto (`-sC`). `-Pn` evita depender de ICMP si el host filtra pings.

9. **Puertos UDP (los más omitidos).** UDP es lento; limitar a los más comunes.
   ```bash
   sudo nmap -Pn -sU --top-ports 50 --max-retries 1 10.10.10.5 -oA puertos/udp-top50
   ```
   Qué hace: busca SNMP (161), TFTP (69), NTP (123), etc.

10. **Detección de SO y topología (opcional, con root).**
    ```bash
    sudo nmap -Pn -O --osscan-guess 10.10.10.5
    ```
    Qué hace: estima sistema operativo y TTL, útil para decidir si el host es Windows o Linux.

11. **Scripts NSE acotados.** Evitar `--script vuln` o `all` sin revisar: algunos scripts son intrusivos.
    ```bash
    sudo nmap -Pn --script "default and safe" -p <puertos> 10.10.10.5 -oA nse/seguro
    ```
    Qué hace: ejecuta solo scripts por defecto que no son intrusivos. Los de categoría `vuln` se lanzan después y por servicio concreto.

12. **Pivoting a segmentos internos (solo si un host tiene segunda interfaz o acceso a otra subred).** Con ligolo-ng se crea la interfaz TUN en el proxy y se añade la ruta (según el README del proyecto):
    ```bash
    # En Kali (proxy), con ligolo-ng ya ejecutándose
    sudo ip tuntap add user $USER mode tun ligolo
    sudo ip link set ligolo up
    # Consola de ligolo: route_add --name ligolo --route 172.16.5.0/24 ; tunnel_start --tun ligolo
    ```
    Alternativa sin TUN, con proxychains y SOCKS (`ssh -D 1080 usuario@pivote` o chisel):
    ```bash
    proxychains4 -q nmap -sT -Pn -p 22,80,445 172.16.5.10
    ```
    Qué hace: hace alcanzable la subred interna desde Kali. Repetir los pasos 5 a 8 contra la nueva subred.

## Qué buscar (indicadores de vulnerabilidad)
- **Hosts que solo aparecen tras el pivote** o en la tabla ARP/rutas de un host comprometido: segmento no visto, candidato a pivote.
- **Servicios de administración expuestos:** SSH con contraseña, RDP (3389), WinRM (5985/5986), Telnet (23).
- **Servicios de datos sin autenticación o mal configurados:** Redis (6379), Docker API (2375 sin TLS), Elasticsearch (9200), MongoDB (27017), NFS (2049, exports con `showmount -e`).
- **SMB (445) y NetBIOS:** versión antigua, firma SMB no requerida, recursos compartidos anónimos.
- **SNMP (161/udp)** con comunidad `public` o `private`: revela rutas, interfaces y usuarios.
- **Puertos solo locales (127.0.0.1)** en la salida de `ss`/`netstat`: servicio interno accesible vía túnel.
- **Tráfico en claro** en la captura: credenciales FTP, HTTP, Telnet o consultas DNS a dominios internos.
- **Versiones con CVE conocido** detectadas por `-sV`; el CVE se valida en el plan de servicios correspondiente.
- **Host con dos interfaces o doble rutas:** señal explícita de pivote, prioridad alta.

## Cómo interpretar y pasar a explotación
- **Puerto abierto con servicio identificado** → pasar al plan de puertos y servicios (`03-puertos-servicios.md`) para enumerar y buscar CVE o configuraciones débiles.
- **Servicio web en 80/443/8080/8443** → plan web (nombre por definir en la biblioteca), con las URLs descubiertas.
- **SMB/RPC/LDAP abiertos** → plan de Active Directory o compartidos, según el contexto del reto.
- **Subred nueva detectada** (por traceroute, ARP o rutas del host) → repetir pasos 5 a 8 sobre esa subred mediante pivote (paso 12).
- **Servicio solo en 127.0.0.1 tras obtener shell** → crear túnel (ligolo-ng o chisel) y escanear el puerto a través del pivote.
- **Captura con credenciales en claro** → usar las credenciales en el servicio correspondiente antes de buscar exploits.
- **Redes sin respuesta a ICMP ni ARP** → aplicar sondas TCP/UDP (paso 6) o escaneo `-Pn`; si nada responde, el host puede estar filtrado o fuera de alcance.

## Errores comunes y trampas
- Usar `-sn` solo con ICMP y concluir que no hay hosts: firewalls bloquean ICMP. Combinar con `-PS`/`-PA`/`-PU`.
- Olvidar que cualquier `-P*` sustituye los valores por defecto de Nmap, no los complementa.
- Escanear sin `sudo` y obtener resultados de conexión TCP completa, más lentos y menos informativos (`-sS` requiere root).
- En Windows, ejecutar `nmap` sin Npcap: los escaneos crudos fallan o devuelven resultados incompletos. Comprobar la instalación de Npcap antes.
- Lanzar `--script vuln` o `all` en un reto compartido: genera ruido y puede tumbar servicios del reto.
- Escanear con `-p-` y `--min-rate` alto en una máquina frágil: puede cerrar servicios; reducir la velocidad.
- Escanear la IP propia desde la misma máquina Windows sin Npcap: Nmap no puede escanear el propio host sin raw sockets.
- Ruta de traceroute con `-I` (ICMP) puede estar bloqueada; probar `-T` (TCP) o UDP por defecto.
- Confundir filtros: `-f` de tcpdump/tshark es de captura (libpcap), `-Y` de tshark es de visualización (Wireshark). No son intercambiables.
- Olvidar cambiar al pivote: los escaneos desde Kali no alcanzan la subred interna sin ruta o túnel; los resultados vacíos no significan "no hay hosts".
- Dejar la captura sin límite de tamaño; usar `-c` o `-C` para rotar archivos.

## Fuentes
- Host Discovery — Nmap Project — https://nmap.org/book/man-host-discovery.html (consultada: opciones `-sn`, `-Pn`, `-PS`, `-PA`, `-PU`, `-PY`, `--traceroute`, privilegios y valores por defecto).
- Host Discovery Techniques — Nmap Project — https://nmap.org/book/host-discovery-techniques.html (solo snippet de búsqueda).
- Nmap Scripting Engine — Nmap Project — https://nmap.org/book/man-nse.html (consultada: `-sC`, `--script`, categorías, `--script-args`).
- Nmap Reference Guide (man) — Nmap Project — https://nmap.org/book/man.html (referencia para `-sV`, `-O`; no consultada directamente).
- Installing Nmap on Windows — Nmap Project — https://nmap.org/book/inst-windows.html (consultada en búsqueda: Npcap necesario para raw packets en Windows; el instalador lo incluye).
- Npcap Users' Guide — Nmap Project / Npcap — https://npcap.com/guide/npcap-users-guide.html (solo snippet de búsqueda).
- Get-NetTCPConnection — Microsoft Learn — https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection (solo snippet de búsqueda).
- tshark man page — Wireshark Foundation — https://www.wireshark.org/docs/man-pages/tshark.html (consultada en búsqueda: `-f` captura libpcap, `-Y` visualización).
- Wireshark display filter reference — Wireshark Foundation — https://www.wireshark.org/docs/dfref/ (referenciada en búsqueda).
- ligolo-ng — nicocha30 (GitHub) — https://github.com/nicocha30/ligolo-ng (README: interfaz TUN, `route_add`, `tunnel_start`, sin privilegios en el agente; consultada en búsqueda).
- Pentesting Network — HackTricks — https://book.hacktricks.xyz/generic-methodologies-and-resources/pentesting-network (solo snippet de búsqueda; los espejos difieren, verificar la versión viva).
- 10 Techniques for Blindly Mapping Internal Networks — NetSPI — https://www.netspi.com/blog/entryid/135/10-techniques-for-blindly-mapping-internal-networks (solo snippet de búsqueda; uso de traceroute para descubrir redes).

## Relación con otros planes
- `01-*.md` (reconocimiento inicial y alcance; nombre por definir) — este plan se aplica después de confirmar el objetivo.
- `03-puertos-servicios.md` — enumeración y versiones de cada puerto encontrado (paso 8 en adelante).
- Planes de servicios web, SMB/AD y criptografía/forense (nombres por definir en la biblioteca) — destino de los hallazgos según el servicio.
- Plan de pivoting y post-explotación (nombre por definir) — ampliación de los pasos 12 y de las conexiones internas.

Nota: los archivos enlazados aún no existen en `analisis/`; los nombres son propuestas pendientes de aprobación.

## Autorización
- Es metodología; aplícala a un objetivo solo si figura en un `ctf/SCOPE.md` confirmado.
- Estado de este plan: propuesta pendiente de aprobación del usuario.
