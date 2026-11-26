# Contexto de Codex

Este archivo contiene notas persistentes específicas para el trabajo realizado
con Codex. No es una fuente de verdad independiente: usa
`../docs/COMMON_CONTEXT.md` y los documentos que enlaza.

## Uso

- Codex es responsable principal de implementar código y ejecutar los comandos
  de desarrollo y validación que indique la tarea.
- Sigue las instrucciones y prioridades de Claude, o directamente las del
  usuario. No cambies el alcance ni las decisiones compartidas por iniciativa
  propia; reporta alternativas a Claude.
- Inspecciona los archivos y cambios existentes antes de editar. Trabaja sobre
  el estado real del repositorio y no reemplaces trabajo ajeno.
- Mantén los cambios enfocados. Informa los comandos exactos que ejecutaste,
  sus resultados y cualquier comprobación que no pudiste realizar.
- Comparte las decisiones y hallazgos que afecten al equipo en los documentos
  comunes, no solo en este archivo.

## Notas de trabajo de Codex

- Tarea completada (2026-11-25): formalizar el handoff de investigación
  compartido de Gemini a Claude sin añadir integraciones externas.
- Archivos relevantes: `GEMINI.md`, `CLAUDE.md`, `README.md`,
  `docs/AI_WORKFLOW.md`, `docs/research/TEMPLATE.md`, `gemini/CONTEXT.md`
  y `claude/CONTEXT.md`.
- Validación: revisión documental de referencias y del flujo; no hay código ni
  comandos de proyecto que ejecutar.
- Handoff / siguiente paso: ambos agentes deben trabajar desde el mismo
  workspace; Claude solicita y lee los informes creados por Gemini.

- GitHub (2026-11-25): el conector de Codex respondió con el usuario autenticado.
  Claude Code usa el binario oficial de GitHub MCP Server 2.3.0, instalado en
  `%LOCALAPPDATA%\HackatonTools` y registrado con alcance local para este
  proyecto. `claude mcp get github` verificó que el servidor arranca. GitHub
  solicita autorización OAuth en el navegador al usar una herramienta por
  primera vez en la sesión.

- Repositorio de Hackaton: `origin` apunta a
  `https://github.com/blacknodo2090/hackaton_machine.git`. La rama local `main`
  sigue a `origin/main` desde el commit inicial de GitHub. Los archivos del
  proyecto siguen como cambios locales, sin publicar. MinGit 2.56.1 quedó
  instalado en `%LOCALAPPDATA%\Programs\MinGit` y disponible en el `PATH`
  del usuario en Windows.

- Graphify 0.9.120 está instalado en un entorno aislado en
  `%LOCALAPPDATA%\Programs\Graphify`. El comando `graphify` está en el
  `PATH` del usuario y la habilidad de Codex se invoca con `$graphify` en
  una sesión nueva. Se verificaron la versión y las dependencias con `pip check`.
