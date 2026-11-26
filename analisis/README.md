# Biblioteca de análisis

15 planes de análisis de un sistema **objetivo** del CTF, cada uno desde un punto
de vista distinto (de lo físico y las conexiones hasta las consultas, la nube y
la post-explotación). Cada plan trae: qué examina, cuándo aplicarlo, herramientas
(Windows nativo vs. Kali/WSL), procedimiento paso a paso con comandos reales,
indicadores de vulnerabilidad, cómo pasar a explotación, trampas y fuentes.

Los elaboró el subagente `investigador` con búsqueda web. Cada plan marca lo
**verificado** en fuente primaria frente a lo **no verificado** (`[NV]`/`[NP]`):
confirma los comandos marcados con `--help`/`man` antes de usarlos en un reto.

## Regla de uso

Son **metodología**. Aplica un plan a un objetivo real **solo** si ese objetivo
figura en un `ctf/targets/<objetivo>/SCOPE.md` confirmado (ver `ctf/PLAYBOOK.md`).
Sin alcance confirmado, los planes se leen y se preparan, pero no se lanzan.

## Índice

### Reconocimiento y superficie de ataque
| Plan | Ángulo | Cuándo usarlo |
|---|---|---|
| [07](07-osint-reconocimiento.md) | OSINT y reconocimiento pasivo | Hay dominio, organización, correos; antes de tocar el objetivo |
| [02](02-red-conexiones.md) | Red y conexiones | IP/host/rango, VPN, red interna, pivoting |
| [03](03-puertos-servicios.md) | Puertos y servicios | Tras el escaneo: enumerar cada servicio |
| [01](01-fisico-hardware.md) | Físico y hardware | Retos de hardware, IoT, firmware, acceso físico |

### Acceso: aplicaciones e interfaces
| Plan | Ángulo | Cuándo usarlo |
|---|---|---|
| [04](04-aplicaciones-web.md) | Aplicaciones web | URL / app web (OWASP: SQLi, XSS, SSRF, SSTI…) |
| [05](05-bases-datos-consultas.md) | Bases de datos y consultas | Formularios, parámetros, APIs de consulta, DNS/LDAP |
| [09](09-autenticacion-sesiones.md) | Autenticación y sesiones | Login, hashes, JWT, cookies, OAuth/SAML, 2FA |
| [14](14-nube-apis.md) | Nube y APIs | Endpoints REST/GraphQL, buckets, metadata/SSRF, IAM |
| [06](06-inalambrico.md) | Inalámbrico | Wi-Fi/BLE/RF/NFC, capturas 802.11 |
| [08](08-ingenieria-social.md) | Ingeniería social | Retos "social"/correo; solo en ejercicio autorizado |

### Artefactos y retos de archivo
| Plan | Ángulo | Cuándo usarlo |
|---|---|---|
| [11](11-binarios-reversing.md) | Binarios y reversing | Ejecutable ELF/PE, crackme |
| [12](12-criptografia.md) | Criptografía | Texto cifrado, clave, RSA/XOR/hashes |
| [13](13-trafico-forense.md) | Tráfico y forense de red | `.pcap`/`.pcapng`, capturas |

### Transversal y post-acceso
| Plan | Ángulo | Cuándo usarlo |
|---|---|---|
| [10](10-configuracion-hardening.md) | Configuración y hardening | Buscar misconfig, defaults, secretos, TLS/cabeceras |
| [15](15-post-explotacion-escalada.md) | Post-explotación y escalada | Tras obtener acceso: enumerar, escalar, pivotar, bandera |

> Nota: algunos planes enlazan entre sí por nombres propuestos durante su
> redacción que no siempre coinciden con el número final; esta tabla es la
> referencia canónica. Pendiente una pasada menor para unificar los enlaces
> internos.
