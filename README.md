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

### Visual Studio Code en Windows

1. Con `code`, `claude`, `gemini` y `codex` disponibles en el `PATH`, haz doble
   clic en `Abrir-VSCode.cmd` para abrir el proyecto completo. Los agentes
   usan las credenciales locales descritas en `docs/AI_WORKFLOW.md`.
2. En la primera apertura, confirma que confías en la carpeta si VS Code lo
   pide y selecciona **Allow Automatic Tasks** si aparece el aviso. Si el
   arranque automático está desactivado y no aparece el aviso, puedes
   activarlo desde **Tasks: Manage Automatic Tasks** en la paleta de comandos
   y volver a abrir el workspace. En las versiones recientes de VS Code ese
   permiso se aplica a todos los espacios de trabajo de confianza.
3. En el panel **Terminal** verás tres terminales interactivos, uno por agente,
   con su rol y contexto cargados por `scripts/start-agents.ps1`. Para volver a
   iniciarlos, elige **Terminal > Run Task > Iniciar IAs**.

### Windows Terminal u otras herramientas

1. Completa el brief y acuerda el stack con el equipo.
2. Abre esta carpeta como raíz del proyecto en la herramienta que vayas a usar.
3. Configura las credenciales localmente siguiendo `docs/AI_WORKFLOW.md`.
4. Abre los tres agentes con su contexto y rol: `.\scripts\start-agents.ps1`
   (Windows Terminal con un panel por agente; ver `-Agentes`, `-Modo` y
   `-Agente` en la ayuda del script).
5. Antes de entregar, ejecuta las comprobaciones del proyecto y anota cómo
   reproducirlas en el README.

No se han elegido framework, comandos de build ni proveedores de servicios.
Agrégalos cuando el equipo tome esas decisiones.
