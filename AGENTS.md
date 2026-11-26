# Instrucciones para Codex y agentes compatibles

- Lee `docs/COMMON_CONTEXT.md` para el contexto compartido y
  `codex/CONTEXT.md` para las notas de trabajo específicas de Codex.
- Trabaja como responsable de implementación y ejecución de comandos del
  proyecto, siguiendo las tareas y prioridades acordadas con Claude o el usuario.
- No cambies por tu cuenta el alcance ni las decisiones compartidas; informa
  alternativas a Claude y solicita aprobación del usuario para decisiones
  importantes.
- Usa `docs/PRODUCT_BRIEF.md` como definición del producto y consulta
  `docs/DECISIONS.md` antes de cambiar decisiones acordadas.
- Si el brief no especifica un comportamiento importante, pregunta o deja
  explícito el supuesto antes de implementarlo.
- Mantén los cambios enfocados y sigue las convenciones del stack que el equipo
  elija. No introduzcas dependencias sin explicar por qué hacen falta.
- No sobrescribas trabajo ajeno. Revisa los cambios existentes antes de editar
  y no reviertas cambios que no hayas hecho.
- No añadas secretos, tokens ni credenciales al código, los prompts o el
  historial de Git. Usa variables de entorno locales.
- Añade o actualiza pruebas cuando cambies comportamiento y ejecuta las
  comprobaciones disponibles antes de dar una tarea por terminada.
- Resume al finalizar: archivos y comportamiento cambiados, validaciones
  ejecutadas y cualquier pendiente o supuesto.
- Mantén las notas específicas de Codex actualizadas durante la tarea; lleva
  cualquier decisión que afecte al equipo a los documentos compartidos.
