# Plan de análisis 11 — Binarios y reversing

- **Punto de vista:** Ofensivo y autorizado. Se trata un ejecutable (ELF o PE) como caja opaca y se busca cómo valida la clave o bandera, qué protecciones tiene y qué primitiva de explotación ofrece. Es una metodología reutilizable: no contiene ningún objetivo concreto.
- **Cuándo aplicarlo:** Cuando el reto entrega un binario ejecutable que pide una clave, valida una contraseña, imprime una bandera tras una condición, o cuando el binario es el paso previo a un reto de pwn (buffer overflow, format string, heap). Si el binario es de tipo servicio remoto, aplicar primero este plan y después el plan de red o pwn.

## Preparación

1. Confirmar que el objetivo figura en `ctf/SCOPE.md` confirmado antes de ejecutar nada. Este plan no lo sustituye.
2. Crear un directorio de trabajo vacío por reto (por ejemplo `retos/<nombre>/`) y copiar allí el binario. Trabajar sobre la copia; conservar el original con hash:
   - `sha256sum <binario>` (Kali/WSL) o `certutil -hashfile <binario> SHA256` (Windows).
3. Tratar el binario como dato no fiable: ejecutarlo solo en entorno aislado (WSL/Kali en máquina de laboratorio, o VM). No correrlo fuera de un entorno de reto.
4. Preparar el entorno:
   - Kali/WSL: `gdb`, `binutils` (`readelf`, `objdump`), `file`, `binwalk` opcional, `radare2` o `rizin`, Ghidra (requiere JDK), `pwntools`, `pwndbg` o GEF, `angr` en un virtualenv aislado.
   - Windows nativo: Ghidra, rizin o radare2 portable, x64dbg, Detect It Easy (DIE), `pefile` en Python, Visual Studio Build Tools solo si se compila algo.
5. Anotar en el informe del reto: nombre del binario, hash, arquitectura, formato, protecciones y cada hipótesis (qué comprueba, dónde, qué entrada espera).

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| `file` | Formato (ELF/PE), arquitectura, bits, stripped o no | Kali-WSL nativo; en Windows, `file` de Git Bash/MSYS o DIE |
| `strings` (binutils) | Cadenas imprimibles; buscar mensajes de éxito/fallo y pistas | Kali-WSL; en Windows vía binutils/MSYS2 o `strings` de Sysinternals |
| `readelf` / `objdump` | Cabeceras, secciones, símbolos, RELRO, desensamblado | Kali-WSL nativo; Windows con binutils (MSYS2) |
| `checksec` (checksec.sh o `pwn checksec` de pwntools) | Protecciones: RELRO, canary, NX, PIE, FORTIFY, RPATH | Kali-WSL. checksec.sh requiere bash y `readelf` |
| Detect It Easy (DIE) | Detectar compilador, packer y formato PE/ELF | Windows nativo |
| `dumpbin /headers /imports` (VS) | Cabeceras e importaciones de PE | Windows nativo (Developer Command Prompt) |
| `pefile` (Python) | Inspección programática de PE | Windows nativo y WSL |
| Ghidra (GUI y `analyzeHeadless`) | Decompilación, análisis en lote, scripts | Windows nativo (requiere JDK); también Kali |
| radare2 (`r2`) | Análisis, desensamblado, parcheo, scripts (`-c`, `-q`) | Kali-WSL nativo; Windows con build/zip oficial |
| rizin (`rizin`) | Fork de radare2 con su propia CLI; mismas tareas básicas | Windows nativo (instalador o portable); Kali |
| GDB + pwndbg / GEF | Depuración dinámica, heap, memoria, ROP helpers | Kali-WSL (pwndbg no es de uso nativo en Windows); GDB nativo en Windows no es la vía recomendada |
| x64dbg | Depuración dinámica de PE | Windows nativo |
| `ltrace` / `strace` | Trazado de llamadas a biblioteca y de sistema | Kali-WSL |
| angr | Ejecución simbólica para encontrar la entrada que llega a un estado | Windows (wheel en PyPI según la página del paquete) y Kali-WSL; verificar versión |
| pwntools | Scripts de explotación, `ELF()`, `process()`, `remote()` | Windows (Python) y Kali-WSL |
| `binwalk` | Detectar contenido empaquetado o embebido | Kali-WSL |

## Procedimiento paso a paso

1. **Triaje.**
   - `file ./reto` → formato, bits, si está "stripped".
   - `sha256sum ./reto` → registrar hash.
   - `strings -n 6 ./reto | less` (o `strings -a -n 6 ./reto | grep -iE "flag|correct|wrong|pass|key|usage"`) → buscar cadenas de éxito/fallo y pistas.
   - `checksec --file=./reto` (checksec.sh) o `pwn checksec ./reto` (pwntools) → RELRO, canary, NX, PIE.
   - Windows: `die reto.exe` y `dumpbin /headers reto.exe`.
   - Resultado esperado: una lista de cadenas candidatas y un perfil de mitigaciones.

2. **Análisis estático — vista general.**
   - Cabeceras y secciones: `readelf -h -S -l ./reto` (ELF) para confirmar arquitectura, PIE, GNU_RELRO/GNU_STACK.
   - Símbolos (si no está stripped): `nm -C ./reto`, `readelf -s ./reto`.
   - Desensamblado rápido: `objdump -d -M intel ./reto | less` o `objdump -d -M intel --no-show-raw-insn ./reto > salida.asm` (guardar en la carpeta del reto, no en el binario).
   - radare2 (Kali/WSL): `r2 -A ./reto` y luego `afl` (lista funciones), `pdf @ main` (desensamblado de `main`), `iz` (cadenas de datos), `ii` (importaciones).
   - rizin: equivalentes similares (`rizin -A ./reto`, `aaa`, `afl`, `pdf @ main`), con la misma lógica.
   - Sustituto no interactivo para scripting: `r2 -q -c 'aaa; afl' ./reto` (no ejecutado en este informe; verificar sintaxis en la versión instalada).

3. **Análisis estático — decompilación.**
   - Ghidra GUI: importar, dejar el análisis automático, buscar `main` y las funciones que referencian las cadenas de éxito/fallo (Search > For Strings, luego "References").
   - Ghidra headless para varios binarios o para automatizar (ver fuentes): `analyzeHeadless <dir_proyecto> <nombre_proyecto> -import ./reto -postScript <script.py> -deleteProject`. En Windows el lanzador suele ser `analyzeHeadless.bat` (no verificado en la fuente consultada; confirmar en la instalación).
   - Renombrar funciones y variables conforme se descubren, y registrar en el informe la dirección de la comprobación.

4. **Análisis dinámico.**
   - Ejecución con entrada controlada: `echo "prueba" | ./reto` y `./reto < entrada.txt`. Registrar la salida de éxito/fallo.
   - Trazado: `ltrace -i ./reto` (llamadas de biblioteca, p. ej. `strcmp`, `memcmp`, `strncmp` que revelan la comparación) y `strace -f ./reto` (llamadas de sistema).
   - GDB con pwndbg o GEF (Kali/WSL): `gdb -q ./reto`, luego `break main`, `run`, `disassemble main`, `checksec` (GEF y pwndbg tienen comando propio), `info functions`, `x/s $rdi` para ver el argumento de `strcmp` en el momento de la llamada.
   - x64dbg (Windows): cargar el PE, poner breakpoint en la llamada de comparación (importaciones de `strcmp`, `memcmp`, `lstrcmpA`) y mirar registros/memoria.
   - Verificar que el ejecutable no ejecute código dañino antes de correrlo; en Windows, usar máquina virtual sin red.

5. **Localizar la comprobación de la clave o bandera.**
   - Desde las cadenas de éxito/fallo, buscar su referencia en el código (Ghidra, radare2 `axt <dir_cadena>`) y subir por el flujo hasta el salto condicional que decide.
   - Desde las funciones de comparación (`strcmp`, `memcmp`, `strncmp`), ver qué se compara y con qué (constante, transformación previa, bucle de XOR o suma).
   - Si la clave se transforma, anotar el algoritmo y reproducirlo en Python (pwntools o script propio) antes de intentar la inversión.
   - Si es una comparación por bucle con constantes, extraer la tabla desde la memoria o la sección `.data`/`.rodata`.
   - Resultado: una hipótesis de entrada válida, comprobada ejecutando el binario con esa entrada.

6. **Parchear o emular.**
   - **Parche de salto (solo si el reto lo permite y el objetivo es ver la bandera desde la condición):** en radare2, `r2 -w -c 's <dirección>; wx 9090' ./reto` (sustituir por el byte o instrucción adecuada; no ejecutado aquí). Copiar el binario antes de parchear. Verificar con `pdf` después.
   - **Emulación/simbólico:** con angr, el patrón `find`/`avoid` busca la entrada que llega a la dirección de éxito y evita la de fallo:
     ```python
     import angr
     proj = angr.Project("./reto", auto_load_libs=False)
     simgr = proj.factory.simgr()
     simgr.explore(find=<dir_exito>, avoid=<dir_fallo>)
     if simgr.found:
         print(simgr.found[0].posix.dumps(0))  # entrada que llega al éxito
     ```
     Sustituir `<dir_exito>` y `<dir_fallo>` por direcciones reales. Si la salida va a stdout, usar `state.posix.dumps(1)` en el criterio. Esto es un esquema basado en la documentación de angr; no se ejecutó en este informe.
   - Si el programa lee de la entrada estándar y muestra "Correct"/"Wrong", angr puede usar lambdas sobre la salida (ver ejemplos de la documentación de angr).

## Qué buscar (indicadores de vulnerabilidad)

- **Comparaciones inseguras:** `strcmp` o `strncmp` con longitud controlada por la entrada, o comparaciones que no cubren la longitud completa.
- **Lectura de la entrada sin límite:** `gets`, `scanf("%s")`, `read` con tamaño mayor que el buffer; cadenas con `strcpy`/`strcat` sin control de tamaño.
- **Format string:** `printf(buf)` donde `buf` viene del usuario. Pistas: `%p`, `%n` en el código.
- **Lógica de validación débil:** la clave se comprueba cliente-side solo con sumas de control o XOR con constantes fijas; la bandera está en la memoria y es recuperable con `ltrace`/GDB.
- **Información en binario:** cadenas de la bandera en `.rodata`, claves hardcodeadas, variables de entorno usadas como secreto.
- **Canary o NX ausente, PIE desactivado, RELRO parcial:** señales de que la explotación posterior (pwn) es más sencilla. Anotar sin asumir que es explotable.
- **Anti-debug o empaquetado:** `ptrace`, `IsDebuggerPresent`, secciones con entropía alta, DIE con packer. Pueden ocultar la lógica real.
- **Retornos dependientes de la entrada:** saltos `jmp` a direcciones calculadas, tablas de salto (`switch`) sobre la entrada.

## Cómo interpretar y pasar a explotación (pwn)

1. Mapear el flujo: desde la entrada hasta la comprobación y desde ahí hasta las funciones con riesgo (`read`, `strcpy`, `printf`). Anotar el tamaño de cada buffer en la pila.
2. Con `checksec`, decidir la vía:
   - Sin canary y sin NX: posible shellcode en pila (si la pila es ejecutable) o ROP si NX está activo.
   - Con PIE: buscar fuga de dirección (format string o lectura de memoria) antes de ROP.
   - Con RELRO completo: no sobrescribir la GOT; apuntar a otros objetivos (retorno, punteros de función).
3. Medir el desplazamiento al retorno con GDB (`pattern create` y `pattern offset` en pwndbg/GEF) o con pwntools (`cyclic`, `cyclic_find`).
4. Recolectar gadgets (`ROPgadget`, `ropper`, o `rizin`/`r2` con búsqueda de gadgets) y verificar con pwntools `ELF` antes de componer la cadena.
5. Redactar el exploit en pwntools, verificar en local (`process()`), y después contra el servicio solo si el alcance lo autoriza.
6. Estado de verificación: cada paso debe marcarse "verificado en local" o "no probado".

## Errores comunes y trampas

- **Confiar en la salida de Ghidra sin verificar:** el decompilador puede renombrar tipos o inferir mal tamaños. Confirmar en el desensamblado.
- **Olvidar la arquitectura:** 32 vs 64 bits cambian convención de llamadas, registros y tamaño de punteros (`$rdi` vs pila en x86).
- **Parchear el original:** siempre trabajar sobre una copia; anotar el parche en el informe.
- **Ejecutar el binario sin aislamiento:** puede modificar el sistema o tener comportamiento malicioso en el entorno del reto.
- **Asumir que `strings` basta:** la bandera puede estar cifrada, dividida en partes o generada en tiempo de ejecución.
- **Diferencias de entorno:** un binario que depende de `ASLR`, variables de entorno, o de la ruta actual puede comportarse distinto en GDB.
- **Herramientas de Windows vs WSL:** pwndbg/GEF y muchas herramientas de pwn se usan en Linux; en Windows conviene WSL o Kali.
- **Versiones y sintaxis:** los nombres de flags y comandos cambian (p. ej. `-postScript` vs `-postscript` en ejemplos de la comunidad); comprobar `--help` de la versión instalada.
- **angr lento o con explosión de estados:** limitar la entrada, usar `auto_load_libs=False` y `find`/`avoid` precisos; de lo contrario se agota la memoria.

## Fuentes

Primarias y oficiales (verificadas en la búsqueda):
- Ghidra Headless Analyzer (README de la versión 9.2, mirror): https://ghidradocs.com/9.2_PUBLIC/support/analyzeHeadlessREADME.html
- Ghidra Headless Analyzer (README de la versión 12.0, mirror): https://ghidradocs.com/12.0_PUBLIC/support/analyzeHeadlessREADME.html
- Guía de scripting headless (comunidad, mirror): https://www.mintlify.com/NationalSecurityAgency/ghidra/scripting/headless
- Libro oficial de radare2, análisis de código: https://book.rada.re/analysis/code_analysis.html
- Libro oficial de radare2, compilación en Windows: https://book.rada.re/first_steps/windows_compilation.html
- Libro oficial de Rizin, Windows: https://book.rizin.re/src/introduction/windows_compilation.html
- Instalación de Rizin (sitio oficial): https://rizin.re/install/
- Documentación de angr, ejemplos: https://docs.angr.io/en/latest/examples.html
- Documentación de angr, cheatsheet (fuente del patrón `explore(find, avoid)`): https://docs.angr.io/en/stable/_sources/appendix/cheatsheet.rst.txt
- Documentación de angr, simulation managers (mencionado en resultados de búsqueda): https://docs.angr.io/core-concepts/pathgroups
- Instalación de angr (PyPI): https://pypi.org/project/angr/
- checksec.sh (página del proyecto): https://www.trapkit.de/tools/checksec.html
- pwndbg (README oficial): https://github.com/pwndbg/pwndbg
- GEF, comando checksec (documentación legacy): https://gef-legacy.readthedocs.io/en/latest/commands/checksec/
- GEF (proyecto): https://github.com/hugsy/gef

Secundarias o no verificadas en detalle:
- HackTricks, sección reversing (mirror en mintlify.wiki; no se abrió la página original): https://mintlify.wiki/HackTricks-wiki/hacktricks/reversing/overview
- Guía de herramientas de línea de comandos (zero-day-archives): https://zero-day-archives.gitbook.io/zero-day-archives/reverse-engineering/reverse-engineering/introduction-to-software-reverse-engineering/reversing-tools-command-line-utilities-for-binary-analysis

Limitaciones de fuentes: la página de checksec.sh no detalla comandos ni las comprobaciones de FORTIFY o RPATH; la página de pwndbg no confirma soporte para Windows; los ejemplos de angr completos no se pudieron leer, por lo que el código de angr se basa en la cheatsheet y en el patrón documentado.

## Relación con otros planes

- **Plan de pwn (binarios explotables):** este plan entrega el perfil de protecciones, el flujo de entrada y las primitivas de explotación que el plan de pwn usa.
- **Plan de criptografía:** si la comprobación de la clave es un algoritmo de cifrado o de hash, el resultado de la inversión pasa al plan de cripto.
- **Plan de forense/stego:** si el binario contiene datos embebidos (`binwalk`, secciones extra), se deriva allí.
- **Plan de web/red:** si el binario es un servicio remoto, el análisis de protocolo pasa al plan de red.

## Autorización

- Este plan es metodológico. No se dirige a ningún objetivo y no reemplaza la verificación de alcance.
- Antes de ejecutar cualquier herramienta sobre un reto concreto, confirmar que el objetivo figura en `ctf/SCOPE.md` confirmado.
- Las acciones de parcheo, ejecución dinámica y explotación se hacen solo dentro del alcance y en entorno aislado.
- Propuesta pendiente de aprobación: incorporar este plan a la biblioteca de metodología del CTF tras revisión del equipo.
