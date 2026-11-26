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

- Graphify periódico (2026-11-25): `scripts/register-graphify.ps1` está
  preparado para registrar `Hackaton-Graphify` a las 19:00, hora de Windows,
  con la sesión de usuario iniciada. `scripts/update_graphify.py` indexa
  encabezados y referencias explícitas del README, el brief, la arquitectura
  y el flujo de coordinación. Los resultados locales van a `graphify-out/`.
- Validación pendiente en la sesión de Juan: generar el primer grafo y
  registrar la tarea. La cuenta aislada de Codex no tiene acceso a la
  instalación de Graphify ni al Programador de tareas.

- Fichas con Gemini (2026-11-25): `scripts/ask-gemini-tool.ps1` genera fichas
  según `docs/tools/TEMPLATE.md` y registra un enlace por programa en
  `docs/tools/README.md`. El flujo está documentado en
  `docs/AI_WORKFLOW.md` y `gemini/CONTEXT.md`.
- Validación: el parser de PowerShell y `tests/test_ask_gemini_tool.ps1`
  pasaron. La prueba con `-Programa nmap -Enfoque "reconocimiento de red y servicios en CTF" -AyudaCmd "nmap --help"`
  capturó la ayuda de Nmap 7.80 e invocó Gemini CLI 0.71.1 desde un
  caché temporal de npm. El CLI terminó con código 41 porque la sesión no
  dispone de `GEMINI_API_KEY`. Quedaron pendientes la generación real de
  `docs/tools/nmap.md` y la verificación de su plantilla y enlace en el índice
  en una sesión autenticada.

- Modelo de Gemini CLI (2026-11-25): `.gemini/settings.json` fija
  `gemini-3.5-flash-lite` para el proyecto y `codebase_investigator`.
  Ambos scripts `ask-gemini*.ps1` usan el mismo valor por defecto.
- Validación: JSON, parser de ambos scripts y prueba simulada de fichas
  correctos. El comando real sin `-m` se ejecutó con el CLI de la caché
  local y quedó pendiente de una sesión autenticada (salida 41 por falta
  de `GEMINI_API_KEY`).

- Iniciador de VS Code (2026-11-25): `Abrir-VSCode.cmd` abre
  `Hackaton.code-workspace`. El workspace ejecuta `scripts/start-agents.ps1`
  con `-Agente` para cada CLI en un terminal integrado dedicado. La tarea
  `Iniciar IAs` permite relanzar los tres agentes en paralelo.
- Validación: el workspace pasó el análisis de JSON estricto y las tres tareas
  resolvieron el script y ejecutaron la CLI simulada correspondiente desde la
  raíz. El lanzador pasó las pruebas con `code` simulado y sin `code` en el
  `PATH`. `code --version` devolvió `1.147.0`, `x64` y código de salida 0,
  con un aviso de acceso denegado de Crashpad.
- Pendiente: probar el doble clic y las tres sesiones reales en VS Code. En la
  versión instalada, el permiso de tareas automáticas es global y se concede
  desde VS Code. El README documenta el aviso inicial y el relanzamiento.
