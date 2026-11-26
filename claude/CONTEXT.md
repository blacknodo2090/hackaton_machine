# Contexto de Claude

Este archivo contiene notas persistentes específicas para el trabajo realizado
con Claude. No es una fuente de verdad independiente: usa
`../docs/COMMON_CONTEXT.md` y los documentos que enlaza.

## Uso

- Claude es el orquestador: recibe prioridades del usuario, define tareas para
  Gemini y Codex, integra resultados y mantiene el registro de decisiones.
- El usuario es el supervisor y tiene la última palabra en decisiones
  importantes de producto, alcance y stack.
- Encarga a Gemini investigación con fuentes; encarga a Codex implementación y
  ejecución de comandos. Evita encargos paralelos que editen los mismos archivos.
- Claude nunca investiga a fondo por su cuenta (instrucción del usuario,
  2026-11-25): toda búsqueda en internet o comparación de opciones se delega a
  Gemini con `.\scripts\ask-gemini.ps1`. Claude solo lee el proyecto, verifica
  puntualmente las fuentes de los informes e integra.
- Si Gemini devuelve 429 / RESOURCE_EXHAUSTED, avisa al usuario (cuota de su
  cuenta) en lugar de investigar en su lugar.
- Antes de proponer o cambiar una solución, contrasta el estado del repositorio
  con el brief y las decisiones compartidas.
- Para recibir resultados de Gemini, revisa `docs/research/<tema>.md` y verifica
  las fuentes. Integra los hallazgos solo después de distinguir evidencia,
  análisis y recomendación; registra decisiones únicamente tras su aprobación.
- Resuelve detalles rutinarios dentro de lo aprobado. Consulta al usuario antes
  de cerrar decisiones importantes o cuando falten requisitos que cambien el
  producto, alcance o stack.
- Mantén `docs/DECISIONS.md` al día y comparte hallazgos que afecten al equipo
  en los documentos comunes, no solo en este archivo.

## Notas de trabajo de Claude

- Tarea activa: función de Gemini para fichas de herramientas (`docs/tools/`).
- Agente asignado y resultado esperado: Codex revisa/termina el borrador
  `scripts/ask-gemini-tool.ps1` + `docs/tools/` y lo prueba con nmap.
- Regla (usuario, 2026-11-25): Claude solo hace el plan y el prompt; Codex
  implementa y ejecuta comandos. Antes de dar comandos, consultar `docs/tools/`.
- Contexto específico de la tarea:
- Informe de Gemini recibido / ruta:
- Hallazgos verificados e integración:
- Supuestos o preguntas pendientes:
- Decisión pendiente de aprobación del usuario:
- Handoff / siguiente paso:
