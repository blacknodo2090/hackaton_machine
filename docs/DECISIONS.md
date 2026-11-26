# Registro de decisiones

Anota aquí las decisiones que afecten al equipo, junto con su contexto.

| Fecha | Decisión | Motivo | Estado |
|---|---|---|---|
| Pendiente | Stack de la aplicación | Por acordar | Abierta |
| 2026-11-25 | Roles de agentes: Claude orquesta y mantiene decisiones; Gemini investiga; Codex implementa y ejecuta comandos; el usuario supervisa y aprueba decisiones importantes | Organización acordada por el usuario para coordinar el trabajo de la hackaton | Acordada |
| 2026-11-25 | Claude no investiga a fondo; toda investigación en internet la hace Gemini, delegada con `scripts/ask-gemini.ps1` (modo headless, solo lectura) | Indicación del usuario; separar roles y que Claude pueda delegar sin intervención manual | Acordada |
| 2026-11-25 | Carpeta de notas de Gemini renombrada de `geminai/` a `gemini/` | Corregir errata y unificar nombres | Acordada |
| 2026-11-25 | El proyecto se orienta a un concurso de simulación de ataque / CTF autorizado. Workspace en `ctf/` con playbook por fases, plantilla por objetivo y barrera de autorización (`SCOPE.md`) antes de atacar | Dirección del usuario para la hackaton | Acordada |
| 2026-11-25 | Entorno de herramientas: kit Python nativo en Windows listo (scapy, impacket, pwntools, nmap 7.80); WSL2+Kali pendiente de instalación manual como admin (`ctf/scripts/install-wsl.ps1`) | WSL requiere elevación y reinicio que la sesión automatizada no puede hacer | Acordada |
| 2026-11-25 | Gemini CLI usa gemini-3.5-flash-lite por defecto (aprobado por el usuario) | 2.5 retirados, 3.8-flash saturado (503), 3.1-pro-preview sin cuota | Acordada |

