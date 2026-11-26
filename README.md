# Hackaton

Base de trabajo para el proyecto de la hackaton. El stack y el alcance todavía
no están definidos; completa primero `docs/PRODUCT_BRIEF.md` y registra las
decisiones técnicas en `docs/DECISIONS.md`.

## Estructura

- `src/`: código de la aplicación.
- `tests/`: pruebas automatizadas.
- `docs/`: brief, arquitectura, decisiones, coordinación y handoffs de
  investigación (`docs/research/`).
- `assets/`: imágenes, archivos de diseño y otros recursos del proyecto.
- `scripts/`: scripts de desarrollo y automatización.
- `docs/COMMON_CONTEXT.md`: punto de entrada de contexto compartido.
- `claude/CONTEXT.md`, `codex/CONTEXT.md`, `gemini/CONTEXT.md`: notas persistentes
  específicas por agente.
- `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`: instrucciones para cada agente.

## Inicio rápido

1. Completa el brief y acuerda el stack con el equipo.
2. Abre esta carpeta como raíz del proyecto en la herramienta que vayas a usar.
3. Configura las credenciales localmente siguiendo `docs/AI_WORKFLOW.md`.
4. Antes de entregar, ejecuta las comprobaciones del proyecto y anota cómo
   reproducirlas en el README.

No se han elegido framework, comandos de build ni proveedores de servicios.
Agrégalos cuando el equipo tome esas decisiones.
