# Contexto común del proyecto

Este documento es la entrada compartida para Claude, Codex, Gemini y el equipo.
Mantiene un resumen y enlaza las fuentes de verdad para evitar que cada agente
trabaje con una versión distinta.

## Estado confirmado

- Este espacio es para un proyecto de hackaton.
- El producto, el alcance y el stack todavía están por definir.
- Los agentes colaboran en la misma carpeta con responsabilidades distintas,
  descritas abajo.

## Roles y autoridad

- **Usuario — supervisor:** define prioridades y tiene la última palabra en
  decisiones importantes de producto, alcance y stack.
- **Claude — orquestador:** coordina el trabajo de los agentes, convierte las
  prioridades del usuario en tareas, integra resultados y mantiene
  `DECISIONS.md`. Puede resolver detalles rutinarios dentro de lo ya aprobado;
  debe presentar al usuario las decisiones importantes para aprobación.
- **Gemini — investigación:** busca información y alternativas, priorizando
  fuentes fiables. Entrega a Claude un resumen con enlaces, evidencia,
  limitaciones y recomendaciones; no convierte una recomendación en decisión.
- **Codex — implementación y comandos:** implementa el código asignado y ejecuta
  los comandos pertinentes del proyecto, incluidas pruebas y comprobaciones.
  Informa qué ejecutó y sus resultados; consulta antes de ampliar el alcance o
  cambiar decisiones acordadas.

Claude coordina el flujo normal: encarga investigación a Gemini cuando haga
falta, decide o consulta al usuario según el impacto, y después asigna a Codex
la implementación y validación. El usuario puede cambiar prioridades o asignar
tareas directamente en cualquier momento.

## Fuentes de verdad

- Producto y alcance: `PRODUCT_BRIEF.md`.
- Decisiones técnicas acordadas: `DECISIONS.md`.
- Estructura y desarrollo local: `ARCHITECTURE.md`.
- Coordinación entre agentes: `AI_WORKFLOW.md`.

Si este resumen contradice alguno de esos documentos, corrige el resumen. No
reemplaces una decisión registrada con una suposición ni dupliques aquí el
contenido completo de esas fuentes.

## Reglas compartidas

- Revisa el brief, las decisiones relevantes y el estado actual del código antes
  de trabajar.
- Si falta un requisito importante, pregunta o deja explícito el supuesto antes
  de implementar.
- Conserva cambios de otras personas y evita editar los mismos archivos en
  paralelo con otro agente.
- Mantén enfocados los cambios; explica dependencias nuevas y valida el
  comportamiento con las comprobaciones disponibles.
- Mantén secretos y credenciales fuera de los archivos versionados.
- Registra en las fuentes compartidas las decisiones que afecten al equipo.
- No atribuyas a otro agente una tarea o decisión que no se le haya asignado.

## Estado de coordinación

- Agente/tarea activa:
- Archivos o área en curso:
- Bloqueos o coordinación necesaria:

Actualiza esta sección cuando coordines tareas entre agentes. No la uses como
sustituto del historial de Git ni como registro de decisiones técnicas.
