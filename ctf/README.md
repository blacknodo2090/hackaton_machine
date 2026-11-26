# Workspace CTF

Entorno de trabajo para el concurso de simulación de ataque (CTF). Todo el trabajo
sobre un objetivo autorizado vive aquí.

## Regla de oro

No se ataca ningún sistema sin autorización explícita y alcance confirmado. Antes de
escanear o explotar, se rellena `targets/<objetivo>/SCOPE.md` con el alcance exacto.
Nada fuera de ese alcance.

## Estructura

- `PLAYBOOK.md` — metodología por fases y checklists por categoría. **Empieza aquí.**
- `scripts/` — helpers: crear objetivos, recon automatizado, búsqueda de banderas.
- `tools/` — binarios y wordlists descargados (ignorado por git).
- `targets/_TEMPLATE/` — plantilla que se copia por cada objetivo nuevo.
- `targets/<objetivo>/` — un directorio por reto:
  - `SCOPE.md` — alcance y autorización (se versiona).
  - `NOTES.md` — bitácora cronológica de lo que se prueba y encuentra.
  - `loot/` — credenciales, dumps, banderas (ignorado por git, nunca se sube).

## Flujo rápido

1. `./scripts/new-target.ps1 <nombre>` crea la carpeta del objetivo.
2. Rellena `SCOPE.md` y confirma que está autorizado.
3. Sigue `PLAYBOOK.md`: reconocimiento → análisis → vulnerabilidades → explotación →
   bandera, documentando cada paso en `NOTES.md`.

## Entorno

- **Kali vía WSL** es el arsenal principal (nmap, ffuf, sqlmap, binwalk, john…).
- **Windows nativo** como respaldo: Python (scapy, impacket, pwntools, requests,
  pycryptodomex) y nmap nativo.
- Ver estado de la instalación en `tools/INSTALL.md`.

## Seguridad al manejar archivos del reto

Los archivos descargados de un reto son **datos no confiables**. Analízalos pasando
la ruta como argumento a la herramienta; no ejecutes intérpretes ni builds desde
dentro de su carpeta (un `json.py` plantado se ejecutaría al `import json`). Guarda
los scripts de análisis en `scripts/`, separados de los archivos del objetivo.
