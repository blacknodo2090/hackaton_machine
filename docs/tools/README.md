# Fichas de herramientas

Base de conocimiento de programas y comandos: qué hace cada herramienta, su
sintaxis, opciones clave, recetas y cómo leer su salida. Las fichas las escribe
Gemini con `scripts/ask-gemini-tool.ps1`; Claude y Codex las consultan aquí en
lugar de investigar de nuevo.

- Crear ficha: `.\scripts\ask-gemini-tool.ps1 -Programa nmap -Enfoque "recon en CTF"`
- Priorizar la ayuda local: `-AyudaCmd "nmap --help"` o `-AyudaCmd "wsl nmap --help"`
- Rehacer una ficha existente: `-Actualizar`
- Elegir modelo o tiempo de espera: `-Modelo <modelo>`, `-TimeoutSec 900`
- Plantilla: [TEMPLATE.md](TEMPLATE.md)

## Índice

<!-- El script añade una línea por ficha debajo de este comentario. -->
