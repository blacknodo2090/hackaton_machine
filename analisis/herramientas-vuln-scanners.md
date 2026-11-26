# Herramientas de escaneo de vulnerabilidades → planes

Catálogo de herramientas del topic de GitHub `vulnerability-scanner` (página 1 y `?page=2`), asignadas a los 15 planes de `analisis/README.md`. Es metodología para el CTF: no ejecuta nada ni investiga un objetivo concreto. Regla aplicada: se priorizan herramientas de consola. Una herramienta con GUI se excluye cuando existe una equivalente de consola; si no la hay y aporta algo único, se incluye marcada como GUI. Cuando una herramienta tiene CLI como interfaz principal y GUI opcional, se incluye como CLI.

Uso: cualquier herramienta solo se lanza contra un objetivo con alcance confirmado en `ctf/SCOPE.md` (ver nota en "Notas y dudas").

## Incluidas (consola)

| Herramienta | Repo (URL) | Interfaz | Plan(es) asignado(s) | Para qué sirve |
|---|---|---|---|---|
| Nuclei | https://github.com/projectdiscovery/nuclei | CLI | 04, 10, 14 | Escáner por plantillas YAML (CVEs, misconfigs, paneles expuestos); admite plantillas propias |
| Vuls | https://github.com/future-architect/vuls | CLI | 10, 15 | Escaneo agentless de CVEs en paquetes de Linux/FreeBSD/contenedores |
| xray | https://github.com/chaitin/xray | CLI | 04 | Escaneo de vulnerabilidades web (`xray webscan`), crawler, modo proxy y PoC personalizados |
| osv-scanner | https://github.com/google/osv-scanner | CLI | 10 | Vulnerabilidades en dependencias usando la base osv.dev |
| commix | https://github.com/commixproject/commix | CLI | 04 | Detección y explotación de inyección de comandos del SO |
| afrog | https://github.com/zan8in/afrog | CLI | 04 | Escaneo de PoCs web para bug bounty y pentest |
| fuxploider | https://github.com/almandin/fuxploider | CLI | 04 | Pruebas de subida de archivos (extensiones y tipos MIME) |
| crawlergo | https://github.com/Qianlitp/crawlergo | CLI | 04 | Crawler con navegador headless para alimentar escáneres web |
| POC-bomber | https://github.com/tr0uble-mAker/POC-bomber | CLI | 04, 15 | Lanza PoCs de alta severidad contra objetivos, con modo de ataque |
| POC-T | https://github.com/Xyntax/POC-T | CLI | 04 | Framework concurrente por plugins para probar PoCs remotos |
| rapidscan | https://github.com/skavngr/rapidscan | CLI | 04, 10 | Escáner web que combina varias herramientas en un único informe |
| Corsy | https://github.com/s0md3v/Corsy | CLI | 04 | Detección de configuraciones erróneas de CORS |
| crlfuzz | https://github.com/dwisiswant0/crlfuzz | CLI | 04 | Búsqueda rápida de inyección CRLF |
| Artemis | https://github.com/CERT-Polska/Artemis | CLI | 04, 10 | Escáner modular que genera informes de configuración y vulnerabilidades |
| Nettacker | https://github.com/OWASP/Nettacker | CLI (+ web GUI opcional) | 02, 03, 04, 10 | Pentest automatizado y escaneo de red/servicios/web (`-m port_scan`, `http_status_scan`, etc.) |
| Raccoon | https://github.com/evyatarmeged/Raccoon | CLI | 02, 03, 07 | Reconocimiento y escaneo de vulnerabilidades sobre un objetivo (`raccoon TARGET`) |
| EMBA | https://github.com/e-m-b-a/emba | CLI (genera informe web) | 01, 10 | Análisis de seguridad de firmware (`sudo ./emba -f <firmware>`) |
| Firmware Analysis Toolkit (FAT) | https://github.com/attify/firmware-analysis-toolkit | CLI (scripts) | 01, 11 | Extracción, análisis binario y emulación de firmware (NV: interfaz no revisada) |
| nmap-vulners | https://github.com/vulnersCom/nmap-vulners | CLI (script NSE de nmap) | 03 | Asocia servicios detectados por `nmap -sV` con CVEs y exploits (`--script vulners`) |
| SSH-Snake | https://github.com/MegaManSec/SSH-Snake | CLI (script shell) | 02, 15 | Descubrimiento de claves y hosts SSH sin ficheros tras el acceso (post-explotación) |
| Terrapin-Scanner | https://github.com/RUB-NDS/Terrapin-Scanner | CLI | 02, 10 | Comprueba si un servidor/cliente SSH es vulnerable a Terrapin (`--connect host:port`) |
| cwe_checker | https://github.com/fkie-cad/cwe_checker | CLI | 11 | Busca patrones de código vulnerable (CWE) en binarios (NV: CLI no leída en README) |
| BinAbsInspector | https://github.com/KeenSecurityLab/BinAbsInspector | CLI | 11 | Análisis estático de binarios con interpretación abstracta (NV: no revisado el README) |
| XAttacker | https://github.com/Moham3dRiahi/XAttacker | CLI (Perl) | 04 | Escáner web con explotación automatizada (NV: no revisado el README) |
| Agentic-Bug-Hunter | https://github.com/awarexone/Agentic-Bug-Hunter | CLI (`bughunter`) | 04 | Caza de bugs con IA: recon → búsqueda → validación → informe (`bughunter hunt`) |
| Pentest-Swarm-AI | https://github.com/Armur-Ai/Pentest-Swarm-AI | CLI (+ TUI; dashboard web en alpha) | 04, 15 | Pentest autónomo multiagente (`pentestswarm scan <target> --scope ...`) |
| pentest-ai (ptai) | https://github.com/0xSteph/pentest-ai | CLI (+ MCP) | 04, 15 | Pentest con IA que revalida hallazgos (`ptai start`) |
| vigolium | https://github.com/vigolium/vigolium | CLI (+ UI web secundaria) | 04, 14 | Escáner dinámico con IA y escaneo rápido (`vigolium scan -t`), API en `server` |
| medusa | https://github.com/Pantheon-Security/medusa | CLI | 10 | Escáner de código con biblioteca de patrones y detección de secretos (`medusa scan .`) |
| PotatoTool | https://github.com/potato-security/PotatoTool | GUI (JavaFX), lanzada desde terminal | 12, 13 | Descifrado, análisis y trazabilidad de red; sin equivalente de consola verificado. Incluida como excepción GUI |

## Excluidas por tener GUI con equivalente de consola

| Herramienta (GUI) | Equivalente de consola que la sustituye | Plan |
|---|---|---|
| DeepAudit (https://github.com/lintsinghua/DeepAudit), interfaz web (`localhost:3000`) | Sustituto parcial: osv-scanner (dependencias) y cwe_checker (binarios). No hay equivalente exacto de auditoría de código con IA por consola en el catálogo | 10 |
| open-kritt (https://github.com/Kritt-ai/open-kritt), interfaz web principal | Su propio modo `./kritt-headless` (consola), y Agentic-Bug-Hunter / Pentest-Swarm-AI como alternativas CLI | 04 |
| BurpBounty (https://github.com/wagiro/BurpBounty), extensión de Burp Suite con GUI | Nuclei (plantillas YAML personalizadas) y xray (PoC personalizados) | 04 |
| L0p4Map (https://github.com/HaxL0p4/L0p4Map), GUI PyQt6 de topología | nmap (descubrimiento y `-sV`), más nmap-vulners para CVEs | 02 |

## Notas y dudas

- **Alcance:** no existe `ctf/SCOPE.md` en el repositorio (comprobado con Glob en `C:\Users\juanp\Desktop\Hackaton`). Este catálogo no investiga ningún objetivo. Además, `analisis/README.md` indica la ruta `ctf/targets/<objetivo>/SCOPE.md`, mientras que la instrucción de la tarea usa `ctf/SCOPE.md`; conviene unificar la ruta.
- **Fuente de la página 2:** `?page=2` devolvió 20 repos (entre ellos pentest-ai, BurpBounty, XAttacker, cwe_checker, Terrapin-Scanner, Artemis, vigolium, medusa, Pentest-Swarm-AI). Como el contenido llega resumido por un modelo, conviene confirmar a mano los nombres antes de usarlos. La página 1 incluye además Nuclei, vuls, xray, osv-scanner, commix, Nettacker, afrog, Raccoon, EMBA, nmap-vulners, fuxploider, crawlergo, POC-bomber, POC-T, rapidscan, SSH-Snake, DeepAudit y open-kritt, entre otras. Dark-Moon, 0security, xalgorix, Cybermes, dianxing y L0p4Map no se han incluido por no estar verificadas o por ser menos relevantes.
- **Verificado en README (CLI/GUI confirmada):** xray, Nettacker, Raccoon, EMBA, fuxploider, POC-bomber, Terrapin-Scanner, medusa, nmap-vulners, pentest-ai, Agentic-Bug-Hunter, Pentest-Swarm-AI, vigolium, PotatoTool (GUI), L0p4Map (GUI), BurpBounty (GUI), DeepAudit (web), open-kritt (web + headless).
- **No verificado (NV):** Nuclei, vuls, osv-scanner, commix, afrog, crawlergo, POC-T, rapidscan, Corsy, crlfuzz, Artemis, cwe_checker, BinAbsInspector, XAttacker, FAT, SSH-Snake. Las clasificaciones CLI de estas se basan en la descripción del topic y en el conocimiento general; antes de usarlas hay que confirmarlas con `--help` o `README`.
- **Vigencia no comprobada:** no se verificó si los repos están archivados o mantenidos (p. ej. Raccoon, rapidscan, xray). Conviene comprobarlo antes de depender de ellos.
- **Huecos de cobertura:** los planes 05 (bases de datos), 06 (inalámbrico), 08 (ingeniería social) y 09 (autenticación y sesiones) no tienen herramienta en este topic. Herramientas como sqlmap, hydra, aircrack-ng o jwt_tool no aparecen en él y serían candidatas a añadir tras una búsqueda específica (no verificadas aquí).
- **Propuesta pendiente de aprobación:** incorporar este catálogo a `analisis/README.md` y decidir si se añaden herramientas fuera del topic para los planes 05, 06, 08 y 09.
