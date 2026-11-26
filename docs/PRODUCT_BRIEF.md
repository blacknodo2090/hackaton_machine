# Brief del producto

## Problema

El equipo necesita resolver retos de un CTF autorizado con rapidez y dejar
evidencia suficiente para que otra persona pueda repetir el trabajo.

## Usuarios y contexto

El usuario supervisa la competición. Claude coordina, Gemini investiga con el
subagente investigador como respaldo y Codex implementa y valida el tooling.
El entorno base es Windows 11 nativo, con Kali en WSL como ampliación prevista.

## Propuesta

La operación se coordina por archivos y combina un playbook por fases, un
espacio por reto y fichas reutilizables de herramientas. La búsqueda de
banderas en archivos locales reduce el trabajo manual. Un `SCOPE.md`
confirmado delimita los objetivos y cada agente tiene un rol definido.

## Alcance de la demo

- Imprescindible — triaje de los artefactos del evento, búsqueda local de
  banderas, fichas de herramientas y notas reproducibles para retos de web,
  pwn, ingeniería inversa, criptografía, forense, esteganografía y red.
- Si hay tiempo — completar el entorno Kali en WSL y ampliar las fichas.
- Fuera de alcance — objetivos sin autorización confirmada en `SCOPE.md`.

## Criterios de éxito

El equipo registra las banderas capturadas y entrega writeups reproducibles.
Otra persona puede recuperar cada bandera siguiendo el `NOTES.md` del reto.

## Restricciones

La operación se limita al tiempo del evento y a los objetivos autorizados en
un `SCOPE.md` confirmado. Los secretos se guardan fuera de Git.
