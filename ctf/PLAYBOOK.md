# Playbook CTF — metodología por fases

Guía operativa para atacar un objetivo autorizado. El principio rector: **no
estancarse**. Si un vector no avanza en un tiempo razonable, se documenta y se rota a
otro. Todo se registra en `targets/<objetivo>/NOTES.md`.

> Barrera de autorización: antes de la Fase 1, `SCOPE.md` del objetivo debe estar
> relleno y confirmado. Nada fuera del alcance.

---

## Fase 0 — Triaje: ¿qué tipo de reto es?

| Señal | Categoría probable | Primera herramienta |
|---|---|---|
| IP / hostname / rango | Red / Host (boot2root) | `nmap` |
| URL / web app | Web | navegador + `curl` + fuzzing |
| Binario ELF/PE sin extensión clara | Pwn / Reversing | `file`, `strings`, `checksec` |
| `.pcap` / `.pcapng` | Forense de red | `tshark` / Wireshark |
| Imagen / audio | Stego | `exiftool`, `binwalk`, `steghide`, `zsteg` |
| Texto cifrado / clave | Cripto | análisis manual + Python |
| `.zip`/`.img`/dump | Forense | `binwalk`, `foremost`, `file` |

Identifica el tipo, crea el target y pasa a la fase correspondiente.

---

## Fase 1 — Reconocimiento

Objetivo: mapear la superficie de ataque sin suposiciones.

- **Red:** `nmap -sC -sV -p- -oA loot/nmap_full <ip>` (todos los puertos + scripts +
  versiones). Luego escaneo dirigido por servicio. UDP si procede: `nmap -sU --top-ports 50`.
- **Web:** fingerprint del stack (headers, `whatweb`), `robots.txt`, `sitemap.xml`,
  `/.git/`, comentarios HTML, JS. Fuzzing de rutas y vhosts con `ffuf`/`gobuster`.
- **Archivo:** `file`, `strings -n 8`, `exiftool`, `binwalk` para carga/metadatos
  ocultos.

Anota TODO lo encontrado en `NOTES.md` antes de profundizar.

---

## Fase 2 — Análisis y enumeración

Profundiza en cada hallazgo:

- **Servicios de red:** enum por servicio — FTP (anónimo), SMB (`enum4linux`,
  `smbclient`), HTTP (ver Web), SSH (banner, usuarios), DB (credenciales por defecto).
- **Web:** endpoints, parámetros, cookies/JWT, formularios, subida de archivos,
  paneles admin, APIs. Prueba valores inesperados en cada parámetro.
- **Binario:** `checksec`, desensamblado con `radare2`/Ghidra, flujo y funciones
  peligrosas (`gets`, `strcpy`, `system`, format strings).
- **Forense/pcap:** sigue flujos TCP, extrae objetos/archivos, busca credenciales en
  claro.

---

## Fase 3 — Identificación de vulnerabilidades

Mapea hallazgos → vectores. No te limites a uno:

- **Web:** SQLi, XSS, LFI/RFI, SSRF, SSTI, bypass de auth, IDOR, deserialización,
  subida sin filtrar, path traversal, inyección de comandos.
- **Pwn:** buffer overflow, format string, use-after-free, ret2libc / ROP.
- **Cripto:** ECB, nonce reusado, RSA débil (e pequeño, factores cercanos), XOR de
  clave corta, padding oracle.
- **Red/host:** credenciales por defecto, versiones con CVE conocido, misconfig.

Si necesitas investigar un CVE o técnica concreta, **delégalo a Gemini** con
`..\scripts\ask-gemini.ps1` (regla del proyecto) e integra el resultado.

---

## Fase 4 — Explotación

- Prueba el vector más prometedor; si no avanza en ~15-20 min, rota al siguiente.
- Prepara varios enfoques en paralelo cuando sea posible.
- Para shells: netcat/`ncat`, reverse shells, estabilización de TTY.
- Para web: Burp/`curl` para manipular peticiones; automatiza con Python (`requests`).
- Documenta el payload exacto que funcionó en `NOTES.md` (reproducibilidad).

---

## Fase 5 — Post-explotación y búsqueda de la bandera

- **Patrones de bandera:** `flag{...}`, `CTF{...}`, `FLAG{...}`, o el formato del
  concurso. Usa `scripts/flag-grep.ps1`.
- **Dónde buscar:** `/home/*`, `/root/`, `/var/www`, variables de entorno, DB,
  historiales (`.bash_history`), metadatos de imágenes, LSB de píxeles, slack space.
- **Escalada de privilegios** si la bandera requiere root: SUID, sudo mal
  configurado, cron, capabilities, kernel exploits.

---

## Fase 6 — Documentación

Cada objetivo cierra con `NOTES.md` que permita reproducir: pasos, comandos,
payloads, y dónde estaba la bandera. No subas banderas ni credenciales a git.

---

## Checklists rápidas por categoría

### Web
- [ ] Headers, cookies, tecnología, `robots.txt`, `/.git/`
- [ ] Fuzzing de directorios y vhosts (`ffuf`/`gobuster`)
- [ ] Cada parámetro: SQLi (`sqlmap`), XSS, LFI, SSTI, inyección de comandos
- [ ] Auth: bypass, fuerza bruta controlada, JWT (alg=none, secreto débil)
- [ ] Subida de archivos, IDOR, SSRF

### Pwn / Binario
- [ ] `file`, `checksec`, `strings`
- [ ] Desensamblado, funciones peligrosas, offset del overflow
- [ ] Protecciones (NX, PIE, canary, RELRO) → elegir técnica
- [ ] Exploit con `pwntools`

### Reversing
- [ ] `strings`, desensamblado estático, decompilador (Ghidra)
- [ ] Localiza la comprobación de la clave/bandera; emula o parchea

### Cripto
- [ ] Identifica el esquema; busca reuso de clave/nonce, claves cortas
- [ ] RSA: comprueba `e`, factoriza `n` (factores cercanos / bases de datos)
- [ ] Resuelve con Python (`pycryptodomex`)

### Forense
- [ ] `file`, `binwalk`, `foremost`, `exiftool`
- [ ] pcap: flujos TCP, objetos HTTP, credenciales en claro
- [ ] Carving de archivos embebidos

### Stego
- [ ] `exiftool`, `binwalk`, `strings`
- [ ] `steghide`/`zsteg`/`stegsolve`, análisis de LSB, canales de color
- [ ] Audio: espectrograma

### Red / Host
- [ ] `nmap -sC -sV -p-`, enum por servicio
- [ ] Credenciales por defecto, versiones con CVE
- [ ] Shell → estabilizar → escalada de privilegios → bandera

---

## Coordinación de agentes por fase

Mapea las fases ofensivas de arriba (Reconocimiento → Bandera) a cada agente.
Todo objetivo requiere un `SCOPE.md` confirmado antes de la Fase 1.

| Fase | Claude (orquesta) | Gemini / investigador (investiga) | Codex (ejecuta) | Usuario |
|---|---|---|---|---|
| 0 Triaje | Clasifica el reto y crea su carpeta | — | — | Elige la prioridad |
| 1 Reconocimiento | Asigna y lee resultados | — | Corre `recon.ps1` (nmap `-sC -sV -p-`), vuelca `loot/` | Confirma `SCOPE.md` |
| 2 Enumeración | Integra hallazgos en `NOTES.md` | Documenta servicios/versiones y técnicas de enumeración | Enumera por servicio (web, SMB, FTP, DB…) | — |
| 3 Vulnerabilidades | Mapea hallazgos → vectores | Investiga CVEs y técnicas de explotación (dentro de `SCOPE.md`) | Prepara PoCs y comprueba precondiciones | — |
| 4 Explotación | Prioriza y rota vectores (~15-20 min) | Aclara el exploit o payload concreto | Escribe y ejecuta el exploit, estabiliza la shell | Aprueba acciones sensibles |
| 5 Post-explotación y bandera | Verifica y registra | Investiga técnicas de escalada para el SO/servicio | Escala privilegios, `flag-grep.ps1`, captura la bandera | Envía la bandera |
| 6 Documentación | Consolida `NOTES.md` y `DECISIONS.md` | Entrega las fuentes | Guarda los payloads que funcionaron | — |

## Bucle de operación en vivo

1. Claude clasifica el reto (Fase 0) y crea su carpeta con
   `ctf/scripts/new-target.ps1 <nombre>` desde la raíz del repositorio.
2. El usuario confirma el `SCOPE.md` del objetivo. Codex ejecuta el
   reconocimiento con `ctf/scripts/recon.ps1` (nmap `-sC -sV -p-`), vuelca a
   `loot/` y registra lo encontrado en `NOTES.md`.
3. Codex enumera cada servicio. Claude mapea los hallazgos a vectores y
   reparte: la investigación de CVEs y técnicas de explotación va a Gemini o al
   subagente investigador (limitada a objetivos en `SCOPE.md`), y Codex prepara
   y ejecuta el exploit del vector más prometedor.
4. Si un vector no avanza en ~15-20 min, se registra y se rota a otro. Tras
   conseguir acceso, Codex escala privilegios si hace falta y busca la bandera
   con `ctf/scripts/flag-grep.ps1`; Claude verifica y el usuario la envía.

Reglas: paralelizar retos distintos con un máximo de cuatro instancias de Codex
y archivos de trabajo separados; no estancarse en un vector; el despacho usa
`scripts/run-codex.ps1` (Codex) y `scripts/run-gemini.ps1` (Gemini), descritos
en [`docs/AI_WORKFLOW.md`](../docs/AI_WORKFLOW.md#despacho-de-tareas).
