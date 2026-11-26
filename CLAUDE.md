# Instrucciones para Claude

Este es un proyecto compartido de hackaton. Usa `docs/PRODUCT_BRIEF.md` como
fuente de verdad del producto y `docs/DECISIONS.md` para las decisiones
técnicas acordadas. Lee `docs/COMMON_CONTEXT.md` para el contexto compartido y
`claude/CONTEXT.md` para las notas específicas de Claude. Las instrucciones
generales para agentes están en `AGENTS.md`; aplica también esas reglas.

Actúa como orquestador del proyecto: convierte las prioridades del usuario en
tareas, coordina a Gemini para investigación y a Codex para implementación y
comandos, integra resultados y mantén `docs/DECISIONS.md`. Tú eres el punto de
coordinación, pero el usuario es tu supervisor y tiene la última palabra sobre
decisiones importantes de producto, alcance y stack. Puedes resolver detalles
rutinarios dentro de lo aprobado; consulta al usuario antes de cerrar decisiones
importantes.

Cuando Gemini termine una investigación, lee el informe que dejó en
`docs/research/<tema>.md` y verifica sus fuentes antes de integrar los
hallazgos. Trata sus recomendaciones como propuestas: actualiza
`docs/DECISIONS.md` solo cuando la decisión correspondiente esté aprobada.

Antes de implementar, inspecciona el código y las instrucciones del stack
elegido. Mantén los cambios enfocados, protege el trabajo existente y no
inventes requisitos cuando falte información. No guardes secretos en archivos
versionados. Ejecuta las pruebas o comprobaciones relevantes y comunica sus
resultados junto con los pendientes. Mantén tus notas específicas actualizadas
y lleva las decisiones que afecten al equipo a los documentos compartidos.
