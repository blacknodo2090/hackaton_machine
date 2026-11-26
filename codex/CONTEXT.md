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

- Hook local de Claude (2026-11-25): `scripts/claude-session-start.ps1` carga
  el contexto y solicita la apertura de Gemini y Codex mediante
  `scripts/start-agents.ps1`. Detecta los procesos del lanzador en esta
  carpeta, incluidos los que aún están abriendo terminales. El modo
  `-Agente` marca la sesión antes de invocar la CLI. La configuración de
  Claude queda en `.claude/settings.local.json`, ignorada por Git.
- Validación: parser de PowerShell 5.1, JSON local,
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test_claude_session_start.ps1`
  y `git diff --check` correctos. Al pasar el JSON por stdin a
  `powershell -NoProfile -File scripts/claude-session-start.ps1`, `startup`
  con opt-out y `resume` devolvieron los cuatro documentos y código 0 en
  568 ms y 467 ms. El comando configurado funcionó desde Git Bash con opt-out
  en 556 ms. `git status --ignored=matching` y `git check-ignore -v`
  confirmaron que se ignora el JSON.
- Pendiente de prueba en la sesión de Juan: abrir Claude de forma interactiva.
  La cuenta de pruebas recibió acceso denegado en la consulta CIM. La
  detección, el lanzamiento y el manejo de ese fallo se probaron con
  simulaciones, sin abrir ventanas.

- Respaldo de investigación (2026-11-25): `scripts/start-agents.ps1` fija
  `-m gemini-3.5-flash-lite` antes de `-i` y también pasa el modelo con
  `-SinPrompt`. Si falla `scripts/ask-gemini.ps1`, Claude delega en
  `.claude/agents/investigador.md` (Haiku). El flujo y la decisión quedaron
  registrados en `docs/AI_WORKFLOW.md`, `claude/CONTEXT.md` y `docs/DECISIONS.md`.
- Validación: `Parser.ParseFile` de PowerShell 5.1 y frontmatter con el parser
  YAML 1.2 incluido en VS Code. Pasaron `powershell.exe -NoProfile
  -ExecutionPolicy Bypass -File tests/test_start_agents.ps1` y el mismo comando
  con `tests/test_claude_session_start.ps1`, ambos con simulaciones.
  `git diff --check` pasó y `git check-ignore` confirmó que Git admite el
  archivo del subagente.
- Pendiente: comprobar la delegación en una sesión real de Claude Code. Falta
  `GEMINI_API_KEY` para Gemini y `ctf/SCOPE.md` para que el respaldo confirme
  qué objetivos del CTF admiten investigación descriptiva o defensiva.

- Ficha de Nmap con Gemini (2026-11-25). Se capturó `nmap --help` y se
  ejecutó una vez `scripts/ask-gemini-tool.ps1` con enfoque de inventario
  defensivo. Gemini CLI terminó con código 41 en 1733 ms. La comprobación
  de `GEMINI_API_KEY` en el entorno de usuario de Windows devolvió `False`
  en la sesión aislada. Se confirmó que la ficha y el enlace siguen pendientes.

- Despacho de tareas (2026-11-25). `scripts/run-codex.ps1` abre la TUI con
  el prompt de archivo y escribe `codexN.exit`. `scripts/run-gemini.ps1`
  selecciona el script de investigación o fichas, carga la clave desde el
  entorno de usuario de Windows y escribe `gemini.<tarea>.exit`. El despacho
  desde ventanas PowerShell visibles está documentado en `docs/AI_WORKFLOW.md`.
- Validación con PowerShell 5.1. `Parser.ParseFile` aceptó ambos lanzadores.
  Pasaron `tests/test_dispatch_launchers.ps1` y `tests/test_ask_gemini_tool.ps1`
  con simulaciones. La sesión aislada carece de la clave de usuario. Se probó
  el reenvío de argumentos de Gemini con un valor simulado. Queda pendiente la
  ejecución interactiva en la sesión de usuario.

- Reorientación del repositorio (2026-11-25). El README, el brief y la
  arquitectura describen la operación del CTF autorizado. Se eliminó `src/`
  tras comprobar que estaba vacía y se documentó `GEMINI_API_KEY` sin valor.
  Gemini y el investigador requieren un `ctf/SCOPE.md` confirmado para
  documentar CVEs, impacto y mitigaciones sobre un objetivo. La ampliación a
  investigación orientada a exploits y el flujo ofensivo entre agentes
  quedaron fuera de esta implementación.
- Validación: ausencia de `src/`, brief y arquitectura sin marcadores,
  `git status --short`, `git diff --check` y búsqueda del prefijo de claves de
  Google sin coincidencias en archivos versionados o sin seguimiento. La prueba
  de extracción Markdown de Graphify quedó bloqueada por falta de acceso
  a Python en la sesión aislada.
- Pendiente del equipo: confirmar `ctf/SCOPE.md`, completar Kali en WSL2
  y reconciliar el resumen de estado de `docs/COMMON_CONTEXT.md` con el brief.

- Playbook CTF (2026-11-26, B-6 parcial). Se añadieron los roles por fase y
  el ciclo de trabajo para triaje, confirmación de alcance, análisis de
  artefactos locales, revisión defensiva y registro de banderas. Quedó
  pendiente la parte solicitada sobre coordinación de exploits y escalada.
