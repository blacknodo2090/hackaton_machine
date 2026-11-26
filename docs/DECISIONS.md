# Registro de decisiones

Anota aquí las decisiones que afecten al equipo, junto con su contexto.

| Fecha | Decisión | Motivo | Estado |
|---|---|---|---|
| Pendiente | Stack de la aplicación | Por acordar | Abierta |
| 2026-11-25 | Roles de agentes: Claude orquesta y mantiene decisiones; Gemini investiga; Codex implementa y ejecuta comandos; el usuario supervisa y aprueba decisiones importantes | Organización acordada por el usuario para coordinar el trabajo de la hackaton | Acordada |
| 2026-11-25 | Claude no investiga a fondo; toda investigación en internet la hace Gemini, delegada con `scripts/ask-gemini.ps1` (modo headless, solo lectura) | Indicación del usuario; separar roles y que Claude pueda delegar sin intervención manual | Acordada |
| 2026-11-25 | Carpeta de notas de Gemini renombrada de `geminai/` a `gemini/` | Corregir errata y unificar nombres | Acordada |
| 2026-11-25 | El proyecto se orienta a un concurso de simulación de ataque / CTF autorizado. Workspace en `ctf/` con playbook por fases, plantilla por objetivo y barrera de autorización (`SCOPE.md`) antes de atacar | Dirección del usuario para la hackaton | Acordada |
| 2026-11-25 | Entorno de herramientas: kit Python nativo en Windows listo (scapy, impacket, pwntools, nmap 7.80); WSL2+Kali pendiente de instalación manual como admin (`ctf/scripts/install-wsl.ps1`) | WSL requiere elevación y reinicio que la sesión automatizada no puede hacer | Reemplazada: el proyecto migra a un equipo dedicado con Kali (ver fila «Migrar todo el proyecto a Kali», 2026-11-26) |
| 2026-11-25 | Gemini CLI usa gemini-3.5-flash-lite por defecto (aprobado por el usuario) | 2.5 retirados, 3.8-flash saturado (503), 3.1-pro-preview sin cuota | Acordada |
| 2026-11-25 | Hook SessionStart local (settings.local.json) carga contexto y abre Gemini+Codex al iniciar Claude | Petición del usuario; local para no abrir ventanas a otros miembros | Acordada |
| 2026-11-25 | Subagente `investigador` (Claude Haiku) como respaldo de Gemini; Gemini sigue siendo el investigador principal con gemini-3.5-flash-lite | Gemini sin clave API; el usuario pidió un respaldo de bajo coste en tokens | Acordada |
| 2026-11-25 | Despacho de Codex mediante lanzador visible durable `scripts/run-codex.ps1` (ventana TUI interactiva, marcador `codexN.exit/.done`); prohibido `codex exec \| Tee` (log UTF-16 ilegible). Máx. 4 Codex, sin editar los mismos archivos en paralelo | PowerShell 5.1 rompía el prompt como argumento y la ventana moría en silencio; el usuario quiere ver siempre el terminal de Codex | Acordada |
| 2026-11-25 | La `GEMINI_API_KEY` no entra al sandbox de Codex. El despacho de Gemini (`ask-gemini*.ps1`) corre en una ventana PowerShell normal que hereda la clave del entorno de usuario, vía `scripts/run-gemini.ps1` | Reducir exposición del secreto; antes se des-excluían todas las `*KEY*` en el sandbox elevado de Codex | Acordada |
| 2026-11-25 | Política de investigación para CTF autorizado: Gemini y el subagente `investigador` pueden investigar CVEs y técnicas ofensivas, pero solo sobre objetivos listados en un `SCOPE.md` confirmado; la ejecución real la hace Codex dentro del alcance | El respaldo defensivo estorbaba para un CTF autorizado; aprobado por el usuario | Acordada |
| 2026-11-25 | Repo reorientado a operación de CTF (no una app): se elimina `src/` (los exploits viven en `ctf/targets/<objetivo>/`) y `PRODUCT_BRIEF.md`/`ARCHITECTURE.md` describen la máquina de agentes + tooling, no un stack de aplicación | El entregable del hackatón es competir en el CTF; confirmado por el usuario | Acordada |
| 2026-11-26 | Migrar todo el proyecto (repo + agentes Claude/Codex/Gemini) a un equipo dedicado con Kali Linux como único SO. La transferencia se hace por un repo **privado** de GitHub: se sube todo desde Windows y se clona en Kali. Los lanzadores PowerShell, el hook de arranque y las pruebas se portan a bash/tmux; las CLIs de los agentes se reinstalan y re-loguean en Kali | El usuario dispone de un equipo con Kali como único sistema; centraliza el arsenal nativo y evita depender de WSL | Acordada |

