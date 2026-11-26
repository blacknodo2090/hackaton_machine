# Flujo de trabajo con agentes

Claude, Codex y Gemini deben trabajar sobre la misma carpeta del proyecto y
usar un contexto compartido y notas específicas por herramienta.

## Contexto

- `COMMON_CONTEXT.md` es el punto de entrada compartido. El brief, las
  decisiones y la arquitectura enlazados allí son las fuentes de verdad.
- Cada herramienta tiene notas propias: `../claude/CONTEXT.md`,
  `../codex/CONTEXT.md` y `../gemini/CONTEXT.md`.
- Lee el contexto común y el de tu herramienta al iniciar una tarea. Guarda
  allí solo notas útiles para esa herramienta; comparte con el equipo cualquier
  decisión o dato que afecte a todos.
- No mantengas copias divergentes del brief, la arquitectura ni las decisiones
  en los contextos específicos.

## Arranque de los agentes

`.\scripts\start-agents.ps1` abre Windows Terminal con Claude (orquestador),
Gemini (investigación) y Codex (implementación) en la raíz del proyecto. Cada
CLI arranca en modo interactivo con un prompt inicial que le pide leer sus
instrucciones, este flujo, el contexto común, sus notas, el brief y las
decisiones; confirmar su rol y esperar instrucciones. Opciones:
`-Agentes claude,codex` (subconjunto), `-Modo paneles|pestanas|ventanas`,
`-Agente gemini` (solo uno, en la terminal actual) y `-SinPrompt`.

## Despacho de tareas

- **Codex.** Claude escribe el encargo en un archivo y termina el prompt
  pidiendo que Codex guarde el resumen en `<MarkerDir>\codexN.done`.
  Claude abre una ventana PowerShell visible con `-NoExit` y ejecuta
  `scripts/run-codex.ps1 -N <N> -Tarea <tarea> -PromptFile <ruta> -MarkerDir <ruta>`.
  El lanzador inicia la TUI interactiva y registra el código en `codexN.exit`.
  Claude espera `codexN.done`, `codexN.exit` o el cierre de la ventana.
  Está prohibido usar `codex exec | Tee`. Ejecuta como máximo cuatro Codex a
  la vez y asigna archivos distintos a cada uno.
- **Gemini.** Claude abre una ventana PowerShell normal con `-NoExit` y
  ejecuta `scripts/run-gemini.ps1 -Script tool|research -Tarea <tarea>` con
  los argumentos del encargo. `tool` usa `ask-gemini-tool.ps1` y `research`
  usa `ask-gemini.ps1`. El lanzador carga `GEMINI_API_KEY` desde el entorno de
  usuario para esa sesión y escribe `gemini.<tarea>.exit` al terminar. La
  clave queda fuera del sandbox de Codex.

## Reglas de colaboración

1. **El usuario supervisa** y tiene la última palabra en prioridades y
   decisiones importantes de producto, alcance y stack.
2. **Claude orquesta:** aclara el objetivo, divide el trabajo, asigna tareas,
   integra los resultados y mantiene `DECISIONS.md`. Puede decidir detalles
   rutinarios dentro de lo aprobado; eleva al usuario las decisiones
   importantes antes de tratarlas como definitivas.
3. **Gemini investiga:** busca información y opciones, y entrega a Claude
   enlaces a las fuentes, evidencia, límites y una recomendación diferenciada
   de los hechos. No implementa ni decide por el equipo salvo que se le asigne
   explícitamente una tarea adicional.
4. **Codex implementa y ejecuta comandos:** cambia el código según el encargo de
   Claude o del usuario, ejecuta comandos de desarrollo y validación relevantes
   y reporta exactamente lo realizado y sus resultados. No cambia por su cuenta
   el alcance ni las decisiones acordadas.
5. Para cada encargo, indica responsable, resultado esperado, restricciones y
   validación. Evita que dos agentes editen los mismos archivos a la vez.
6. Cada agente revisa el estado actual y conserva los cambios existentes. Al
   cerrar, Claude consolida los hallazgos y decisiones compartidos; las notas
   particulares se mantienen en el contexto de cada herramienta.

## Entrega de investigación de Gemini a Claude

El handoff se realiza mediante archivos del workspace compartido, no depende
de que las conversaciones de las CLI se comuniquen entre sí:

1. Claude encarga a Gemini una pregunta concreta, contexto, alcance y el
   resultado que necesita. Claude no hace investigación a fondo por su cuenta:
   Gemini es el investigador principal. Vía preferida:
   `.\scripts\run-gemini.ps1 -Script research -Tarea <tarea> -Tema <tema> -Pregunta "..." -Contexto "..."`,
   que ejecuta Gemini en modo solo lectura (`--approval-mode plan`) y guarda
   su respuesta como informe. También puede encargarse desde la terminal de
   Gemini con la plantilla de abajo.
2. Gemini crea un informe nuevo en `docs/research/<tema>.md`, siguiendo
   `docs/research/TEMPLATE.md`. Usa un nombre corto en minúsculas con guiones;
   no sobrescribas informes anteriores.
3. Gemini termina indicando a Claude la ruta del informe, un resumen breve y
   las incertidumbres o decisiones pendientes.
4. Claude lee el informe y comprueba las fuentes antes de integrar resultados.
   Si hay una decisión importante, presenta opciones al usuario y registra
   solo las decisiones aprobadas en `DECISIONS.md`.

Los informes separan hechos respaldados por fuentes, análisis y recomendación.
Gemini no modifica el brief ni el registro de decisiones como parte de una
investigación; cualquier propuesta sigue pendiente de revisión y aprobación.

### Respaldo de investigación

Si `scripts/ask-gemini.ps1` falla por falta de clave API, 429
(`RESOURCE_EXHAUSTED`), 503 u otro error, Claude delega el mismo encargo en
`investigador` (Claude Haiku). El subagente entrega un informe en
`docs/research/<tema>.md` con la misma plantilla.

### Fichas de herramientas con Gemini

`.\scripts\run-gemini.ps1 -Script tool -Tarea ficha-nmap -Programa nmap -Enfoque "reconocimiento de red y servicios en CTF" -AyudaCmd "nmap --help"`

El script requiere Gemini CLI autenticado en la sesión y le envía el encargo
por stdin en modo `plan`. Gemini consulta documentación oficial y manuales.
Si `-AyudaCmd` termina correctamente, el script adjunta hasta 20.000 caracteres
de su salida para documentar la versión instalada. Si falla, Gemini trabaja con
las fuentes web.
El script guarda la ficha en `docs/tools/<programa>.md` según
`docs/tools/TEMPLATE.md` y añade su enlace una vez al índice
`docs/tools/README.md`. Usa `-Actualizar` para reemplazar una ficha existente.
`-Modelo` selecciona el modelo y `-TimeoutSec` limita cada comando (900 s por
defecto). Ante un 429 / `RESOURCE_EXHAUSTED`, la ejecución avisa y conserva los
archivos existentes.

## Configuración de credenciales

- Instala y autentica cada CLI por separado según la documentación oficial de
  su proveedor.
- No copies claves entre herramientas ni las incluyas en prompts, archivos
  versionados o capturas.
- Guarda las variables locales en `.env` (ignorado por Git) y comparte solo
  sus nombres mediante `.env.example`.
- No se incluye configuración de permisos ni de modelos; el equipo debe elegir
  esos valores según sus cuentas y políticas.

## Plantillas de tarea

**Claude a Gemini — investigación**

> Investiga [pregunta]. Prioriza fuentes fiables y entrega enlaces, hechos
> verificados, limitaciones, alternativas y recomendación. Guarda el informe en
> `docs/research/<tema>.md` usando `docs/research/TEMPLATE.md` y al terminar
> compárteme su ruta. No presentes una recomendación como decisión aprobada ni
> edites `docs/DECISIONS.md`.

**Claude a Codex — implementación**

> Lee `AGENTS.md`, `docs/COMMON_CONTEXT.md`, `codex/CONTEXT.md`, el brief y las
> decisiones relevantes. Implementa [resultado concreto]. No cambies
> [restricciones]. Ejecuta [comandos de validación] y reporta cambios, comandos,
> resultados y pendientes. Conserva el trabajo existente.
