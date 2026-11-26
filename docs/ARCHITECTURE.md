# Arquitectura operativa

El equipo usa este repositorio para competir en un CTF autorizado.

## Herramientas y CLIs

- Claude Code coordina las tareas y mantiene las decisiones.
- Gemini CLI investiga y entrega informes en `docs/research/`. El subagente
  `investigador` cubre ese rol cuando Gemini falla.
- Codex CLI implementa el tooling y ejecuta las comprobaciones del proyecto.
- El inventario de Windows incluye Python con Scapy, Impacket y pwntools,
  además de Nmap 7.80. La instalación de Kali en WSL2 sigue pendiente.

## Componentes y flujo

Los agentes comparten las decisiones, fichas e informes en `docs/`. El área
`ctf/` reúne `targets/`, `scripts/` y `PLAYBOOK.md`. Cada reto tiene un
directorio bajo `ctf/targets/` con sus evidencias y notas.

El equipo confirma el alcance, clasifica los retos, revisa los artefactos
entregados por el evento y anota los hallazgos. Cuando obtiene una bandera,
registra la evidencia y los pasos de reproducción en el writeup.

`scripts/start-agents.ps1` inicia las sesiones con sus roles.
`scripts/run-codex.ps1` y `scripts/run-gemini.ps1` despachan tareas a las
respectivas CLIs. El hook `scripts/claude-session-start.ps1` carga el contexto
compartido al abrir Claude y puede iniciar las sesiones que falten.

## Operación local

1. Configura las CLIs con las credenciales locales de `docs/AI_WORKFLOW.md`.
   El entorno previsto incluye Nmap y admite WSL como complemento opcional.
2. Abre `Abrir-VSCode.cmd`, ejecuta `scripts/start-agents.ps1` o abre Claude
   con su hook local configurado. El README describe cada vía de inicio.
3. Verifica el `ctf/SCOPE.md` confirmado antes de trabajar en un objetivo.
   Guarda las evidencias en `loot/` dentro del directorio del reto y documenta
   en `NOTES.md` los pasos y resultados que permitan reproducir el hallazgo.
