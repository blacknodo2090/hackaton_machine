# Hackaton

Este repositorio reúne los agentes, las herramientas y el playbook para
competir en un CTF autorizado. El alcance acordado está en
`docs/PRODUCT_BRIEF.md` y las decisiones del equipo en `docs/DECISIONS.md`.

## Estructura

- `ctf/`: espacio de trabajo de la competición, con playbook, scripts y retos.
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

1. Revisa el brief y confirma el alcance en `ctf/SCOPE.md` antes de trabajar en
   un objetivo.
2. Abre esta carpeta como raíz del proyecto en la herramienta que vayas a usar.
3. Configura las credenciales localmente siguiendo `docs/AI_WORKFLOW.md`.
4. Abre los tres agentes con su contexto y rol: `.\scripts\start-agents.ps1`
   (Windows Terminal con un panel por agente; ver `-Agentes`, `-Modo` y
   `-Agente` en la ayuda del script).
5. Antes de entregar, ejecuta las comprobaciones del proyecto y anota cómo
   reproducirlas en el README.

### Arranque automático con Claude

En una sesión nueva de Claude Code en este proyecto, el hook local carga el
contexto compartido, las notas de Claude, el brief y las decisiones. También
abre los agentes Gemini y Codex que falten y añade al contexto el estado de
la apertura. Si Claude se abrió desde el lanzador o VS Code, solo carga el
contexto.

Para mantener la carga de contexto y desactivar la apertura de los agentes,
ejecuta `$env:HACKATON_NO_AUTOSTART = '1'` en PowerShell antes de abrir Claude
desde esa terminal.

Para activarlo en otro equipo, copia este bloque en tu
`.claude/settings.local.json`. Si ya tienes otros ajustes, añade esta entrada
a `hooks.SessionStart` y conserva las que ya estén. Git ignora este archivo.
El comando usa la sintaxis de Git Bash. Si Claude ejecuta los hooks con
PowerShell, usa `$env:CLAUDE_PROJECT_DIR` en el valor de `command`.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$CLAUDE_PROJECT_DIR/scripts/claude-session-start.ps1\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```
