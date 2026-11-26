# Plan de análisis 15 — Post-explotación y escalada

- **Punto de vista:** Atacante con acceso inicial no privilegiado (shell, WinRM, sesión web o credencial válida) dentro de un CTF autorizado. Objetivo: enumerar el host desde dentro, escalar a root/SYSTEM o a un usuario con acceso a la bandera, moverse lateralmente si el alcance lo exige y localizar la bandera.
- **Cuándo aplicarlo:** Solo después de haber obtenido ejecución de comandos o sesión en un objetivo que figure en un `ctf/SCOPE.md` confirmado. No es un plan de reconocimiento externo ni de explotación inicial (eso corresponde a otros planes de `analisis/`).

> **Estado de verificación.** Este plan es una metodología genérica. No investiga ningún objetivo concreto, por lo que no se ha consultado `ctf/SCOPE.md` (no existe en el repositorio en este momento). Cualquier uso sobre un host requiere que el objetivo esté confirmado en ese archivo. Las marcas [V] indican fuente primaria consultada directamente; [NV] indica dato solo obtenido de resultados de búsqueda o fuentes secundarias, pendiente de verificación.

## Preparación

1. Confirmar el alcance: `ctf/SCOPE.md` con el host/IP, la fase permitida (post-explotación) y las restricciones (p. ej. si se permite movimiento lateral o solo escalada local).
2. Anotar el punto de partida: usuario, SO, versión de kernel/Windows, método de acceso. Guardar en un directorio propio de trabajo, no en carpetas del sistema.
3. Preparar un servidor local para transferir herramientas (p. ej. `python3 -m http.server` en Kali o WSL; en Windows, `certutil` o `Invoke-WebRequest` del lado atacante). Verificar hashes de las herramientas descargadas.
4. Estabilizar la shell si es interactiva (Linux: `script -qc /bin/bash /dev/null`, `stty`). Windows: preferir la sesión de PowerShell ya disponible.
5. Tener a mano los catálogos de referencia: GTFOBins para Linux, LOLBAS para Windows, y una copia local de las guías de PEASS-ng.
6. Registrar cada hallazgo con: comando ejecutado, salida relevante, hipótesis. Esto sirve para el informe del CTF y para no repetir pasos.
7. Límite de ruido: no ejecutar exploits de kernel o de servicios sin antes confirmar la versión exacta y que el vector figura en la lista de vectores del plan (riesgo de romper la máquina del CTF).

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| linPEAS (PEASS-ng) [V] | Enumeración automatizada de vectores de escalada en Linux/Unix (SUID, sudo, cron, capabilities, permisos de escritura, credenciales). Se distribuye como `.sh` y binarios. | Kali-WSL / Linux (se ejecuta en el objetivo Linux) |
| winPEAS (PEASS-ng) [V] | Equivalente para Windows: servicios, tareas, registro, tokens, credenciales. Variantes `.bat`, `.ps1` y `.exe`. | Nativo Windows (se ejecuta en el objetivo Windows) |
| pspy [V] | Monitoriza procesos y cron jobs de otros usuarios sin root, leyendo `/proc` y vigilando eventos con inotify. Útil para detectar tareas programadas ocultas. | Kali-WSL / Linux (en el objetivo) |
| GTFOBins [V] | Catálogo de binarios Unix que se pueden abusar en contextos Unprivileged, Sudo, SUID y Capabilities; indica el comando exacto por función (shell, file read/write, privesc). | Navegador (cualquiera) / consulta de referencia |
| LOLBAS [V] | Catálogo de binarios, scripts y librerías de Windows con funciones como Execute, Download, Credentials, UAC bypass. | Navegador (cualquiera) / consulta de referencia |
| Comandos nativos del SO (`find`, `getcap`, `sudo -l`, `id`) | Enumeración manual que confirma o descarta lo que reporten las herramientas. | Kali-WSL / Linux |
| Comandos nativos Windows (`whoami /all`, `reg query`, `sc qc`, `schtasks`, `icacls`, `cmdkey`) | Enumeración manual de privilegios, servicios, registro y credenciales. | Nativo Windows |
| GodPotato [V] | Escalada a SYSTEM desde cuentas con `SeImpersonatePrivilege` (ImpersonatePrivilege) mediante el abuso de RPCSS/DCOM. Según el README, soporta Windows Server 2012–2022 y Windows 8–11. | Nativo Windows (se ejecuta en el objetivo) |
| PrintSpoofer [V] | Escalada a SYSTEM con `SeImpersonatePrivilege` abusando del Print Spooler. Según el README, indicado para Windows 10 y Server 2016/2019. | Nativo Windows (se ejecuta en el objetivo) |
| mimikatz [V] | Extracción de credenciales de memoria (hashes, tickets Kerberos, PIN), pass-the-hash y pass-the-ticket. Exige privilegios elevados (p. ej. SeDebugPrivilege) y genera alto ruido en EDR. | Nativo Windows |
| BloodHound / SharpHound [V parcial] | Mapeo de rutas de ataque en Active Directory a partir de la relación entre usuarios, grupos y permisos. Solo aplicable si el CTF incluye un dominio AD. La página oficial consultada describe la edición Enterprise; las particularidades de Community Edition y BloodHound.py [NV] deben verificarse en la documentación oficial. | SharpHound: nativo Windows (dominio). BloodHound.py: Kali-WSL |
| Ligolo-ng / chisel / proxychains (pivoting) [NV] | Túneles para acceder a redes internas desde el host comprometido. No se han verificado en esta sesión; ver fuentes de pivoting en el plan de red. | Kali-WSL (cliente) + objetivo |

## Procedimiento paso a paso

### Linux

1. **Identidad y entorno.** Confirma usuario, grupos y entorno.
   ```bash
   id; whoami; hostname; uname -a; cat /etc/os-release; env
   ```
   Qué hace: fija el contexto (grupos como `docker`, `lxd`, `adm`, versión de kernel para búsqueda de exploits).

2. **Usuarios y sesiones.** Localiza otros usuarios, shells válidas y su home.
   ```bash
   cat /etc/passwd | grep -v nologin | grep -v false; ls -la /home /root 2>/dev/null
   ```
   Qué hace: identifica cuentas con shell real y directorios de usuarios objetivo (donde suele estar `user.txt`).

3. **Sudo.** Revisa qué puede ejecutar el usuario actual como root y sin contraseña.
   ```bash
   sudo -l
   ```
   Qué hace: lista comandos permitidos. Cada binario listado se cruza con GTFOBins (contexto Sudo). Atención a wildcards y variables de entorno (`env_keep`).

4. **SUID y SGID.** Busca binarios con bit SUID/SGID.
   ```bash
   find / -perm -4000 -type f 2>/dev/null
   find / -perm -2000 -type f 2>/dev/null
   ```
   Qué hace: lista binarios que ejecutan con el propietario (a menudo root). Se contrastan con GTFOBins (contexto SUID) y con la versión del paquete. Descartar rutas estándar conocidas tras verificarlas.

5. **Capabilities.** Busca capacidades de Linux asignadas a binarios.
   ```bash
   getcap -r / 2>/dev/null
   ```
   Qué hace: detecta capacidades como `cap_setuid+ep` o `cap_dac_read_search` que pueden dar escalada sin SUID. Verificar en GTFOBins (contexto Capabilities).

6. **Tareas programadas y procesos de otros usuarios.** Revisa cron y observa procesos.
   ```bash
   cat /etc/crontab; ls -la /etc/cron.* /var/spool/cron/crontabs 2>/dev/null
   systemctl list-timers --all 2>/dev/null
   ./pspy64 -pf -i 1000
   ```
   Qué hace: lista tareas definidas; `pspy64` (con `-p` comandos y `-f` eventos de sistema de archivos, `-i` intervalo en ms) revela tareas ejecutadas por root que no aparecen en los ficheros. Dejar pspy corriendo unos minutos. Según la documentación, procesos muy cortos pueden perderse.

7. **Escritura en rutas privilegiadas y PATH.** Busca scripts o directorios escribibles usados por root.
   ```bash
   find / -writable -type f -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | grep -v "^/tmp" | head -n 100
   echo $PATH
   ```
   Qué hace: detecta scripts de cron o servicios modificables y directorios escribibles en el PATH que root usa.

8. **Servicios y puertos internos.** Busca servicios que escuchan solo en localhost (candidatos a pivote o escalada).
   ```bash
   ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null
   ```
   Qué hace: un servicio local puede tener una vulnerabilidad o credencial. Acceder con `curl` o un túnel si es necesario.

9. **Credenciales y secretos.** Busca contraseñas, claves y configuraciones.
   ```bash
   grep -RIlE "(pass|passwd|password|secret|token)" /var/www /opt /home /etc 2>/dev/null | head -n 50
   find / -name "id_rsa*" -o -name "*.kdbx" -o -name ".bash_history" 2>/dev/null
   ```
   Qué hace: localiza credenciales en código, configuraciones y historiales. Reutilizar credenciales encontradas solo dentro del alcance.

10. **Herramientas automatizadas.** Ejecuta linPEAS y guarda la salida.
    ```bash
    ./linpeas.sh -a > /tmp/linpeas_out.txt 2>&1
    ```
    Qué hace: automatiza los puntos 3–9 y añade comprobaciones de kernel, contenedores y rutas. Leer la salida con criterio: muchos hallazgos son falsos positivos. Nota: en el objetivo usar un directorio de trabajo propio; el ejemplo usa `/tmp` solo como ilustración.

11. **Kernel (último recurso).** Solo si la versión coincide con un exploit verificado y el riesgo de caída es aceptable.
    ```bash
    uname -r
    ```
    Qué hace: la versión exacta permite buscar un exploit concreto (fuentes de CVE y PoC en el plan de explotación).

12. **Localizar la bandera.**
    ```bash
    find / -name "user.txt" -o -name "root.txt" -o -name "flag*.txt" 2>/dev/null
    ```
    Qué hace: localiza ficheros de bandera típicos. Ver sección de captura.

### Windows

1. **Identidad y privilegios.** Confirma cuenta y privilegios de token.
   ```powershell
   whoami /all
   ```
   Qué hace: muestra grupos y privilegios (`SeImpersonatePrivilege`, `SeBackupPrivilege`, `SeRestorePrivilege`, `SeDebugPrivilege`, `SeTakeOwnershipPrivilege`, `SeLoadDriverPrivilege`). Estos privilegios, según la documentación de Microsoft [V], permiten, respectivamente, suplantar clientes, leer cualquier fichero (backup), escribir cualquier fichero (restore), depurar cualquier proceso, tomar propiedad de objetos y cargar drivers.

2. **Sistema y parches.**
   ```powershell
   systeminfo
   Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
   ```
   Qué hace: versión, build y parches. Con esto se decide si un exploit de kernel es razonable (ver riesgos).

3. **Usuarios y grupos.**
   ```powershell
   net user
   net localgroup administrators
   ```
   Qué hace: identifica administradores y cuentas de interés (p. ej. Administrator, usuarios de servicio).

4. **Servicios y rutas sin comillas/permisos.**
   ```powershell
   Get-CimInstance Win32_Service | Select-Object Name, StartName, PathName, State | Where-Object { $_.PathName -notmatch '"' -and $_.PathName -match ' ' }
   icacls "C:\Program Files\Algún\Servicio.exe"
   sc qc <NombreServicio>
   ```
   Qué hace: detecta rutas sin comillas con espacios (unquoted service path) y permisos de escritura en binarios de servicios que corren como SYSTEM. Confirmar con `icacls` que el usuario tiene `(M)` o `(F)`.

5. **Tareas programadas.**
   ```powershell
   schtasks /query /fo LIST /v | findstr /i "Nombre Tarea Usuario Ejecutar"
   ```
   Qué hace: lista tareas, usuario de ejecución y ruta del ejecutable. Si la tarea corre como SYSTEM y su binario es escribible, hay vector.

6. **AlwaysInstallElevated.** Comprueba la política de instalación elevada.
   ```powershell
   reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
   reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
   ```
   Qué hace: si ambos valores valen `0x1`, un usuario puede instalar un MSI con privilegios de SYSTEM. La ruta y el valor se toman de HackTricks [NV] (fuente secundaria); verificar en la documentación oficial de Windows Installer antes de confiar en ella (la página de Microsoft consultada devolvió 404).

7. **Credenciales guardadas y ficheros sensibles.**
   ```powershell
   cmdkey /list
   reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 2>$null
   Get-ChildItem -Path C:\Users -Include *.txt,*.kdbx,*.config,*.xml,*.ps1 -Recurse -ErrorAction SilentlyContinue | Select-String -Pattern "password|pass" -List
   ```
   Qué hace: lista credenciales del Administrador de credenciales, autologon en Winlogon y ficheros con contraseñas.

8. **Automatizar con winPEAS.**
   ```powershell
   .\winPEASx64.exe quiet > C:\Users\Public\winpeas_out.txt
   ```
   Qué hace: ejecuta todas las comprobaciones y deja la salida en fichero. Puede ser detectado por Defender; el plan no recomienda exclusiones de AV sin autorización explícita del CTF.

9. **Vectores de token (si hay SeImpersonate).** Con `SeImpersonatePrivilege`, probar GodPotato o PrintSpoofer según la versión.
   ```powershell
   .\GodPotato-NET4.exe -cmd "cmd /c whoami"
   .\PrintSpoofer64.exe -i -c "cmd /c whoami"
   ```
   Qué hace: si la salida es `nt authority\system`, la escalada funcionó. Nota: los nombres de binario y flags exactos deben confirmarse en el README de la versión descargada (no se ha ejecutado en esta sesión).

10. **Localizar la bandera.**
    ```powershell
    Get-ChildItem -Path C:\Users -Recurse -Include user.txt,root.txt,flag*.txt -ErrorAction SilentlyContinue
    ```
    Qué hace: busca la bandera en los escritorios de usuarios y Administrador.

## Qué buscar (vectores de escalada)

| Vector | Linux | Windows | Cómo confirmar |
|---|---|---|---|
| Sudo mal configurado | `sudo -l` con binarios de GTFOBins (contexto Sudo) | — | Ejecutar el comando de GTFOBins en la página del binario |
| SUID/SGID | `find / -perm -4000` + GTFOBins | — | Comprobar propietario y versión |
| Capabilities | `getcap -r /` (p. ej. `cap_setuid`) | — | GTFOBins contexto Capabilities |
| Cron / tareas programadas | `/etc/crontab`, `pspy` | `schtasks /v`, tareas como SYSTEM | Binario/script escribible por el usuario |
| PATH / ficheros escribibles | Directorios del PATH escribibles, scripts escribibles | Servicios con binario escribible | `ls -la`, `icacls` |
| Kernel | `uname -r` + exploit verificado | `systeminfo` + parches | Versión exacta; último recurso |
| Tokens/privilegios | — | `SeImpersonatePrivilege` (GodPotato, PrintSpoofer), `SeBackupPrivilege`, `SeRestorePrivilege`, `SeTakeOwnershipPrivilege` | `whoami /priv` |
| Servicios sin comillas | — | Rutas con espacios sin comillas | `Get-CimInstance Win32_Service` |
| AlwaysInstallElevated | — | HKCU y HKLM con `0x1` | `reg query` |
| Credenciales | Historial, `.env`, claves SSH, configuraciones web | `cmdkey /list`, Winlogon, ficheros | `grep`/`Select-String` |
| Contenedores/grupos | Grupos `docker`, `lxd`, `adm` | Grupos de operadores de backup | GTFOBins / documentación del grupo |
| Active Directory (si aplica) | — | Rutas de ataque con BloodHound | Mapa de grafos; verificar cada arista antes de explotar |

## Cómo interpretar y capturar la bandera

- **Interpretar la salida de enumeración.** Separar hechos (salida literal de un comando) de hipótesis (un vector posible). Un hallazgo de linPEAS no es un vector confirmado hasta reproducirlo a mano.
- **Priorizar.** Orden sugerido: sudo y tokens (rápidos y fiables), luego tareas programadas y servicios, después credenciales, y por último kernel.
- **Escalar y verificar.** Confirmar la escalada con `id` / `whoami` (Linux) o `whoami` (Windows esperando `nt authority\system`). Anotar la evidencia.
- **Captura de la bandera.** Ubicaciones típicas: Linux `/home/<usuario>/user.txt` y `/root/root.txt`; Windows `C:\Users\<usuario>\Desktop\user.txt` y `C:\Users\Administrator\Desktop\root.txt`. Leer la bandera con `cat` o `type` y registrar el valor exacto.
- **Formato.** Respetar el formato de envío que indique el `ctf/SCOPE.md`; no publicar banderas en repositorios versionados.
- **Limitaciones.** Si el CTF exige fases encadenadas (p. ej. credencial → usuario → root), guardar cada credencial y estado intermedio en el directorio de trabajo para poder continuar.

## Errores comunes y trampas

- **Confiar en linPEAS sin verificar.** Muchos avisos son falsos positivos o rutas ya conocidas; verificar a mano.
- **Ejecutar exploits de kernel sin confirmar versión.** Puede provocar un kernel panic o BSOD y perder el acceso.
- **No usar `2>/dev/null` o `-ErrorAction SilentlyContinue` en búsquedas amplias.** La salida se llena de errores de permisos y oculta resultados.
- **Olvidar que pspy no ve todo.** Procesos muy cortos pueden perderse; dejar el monitor más tiempo y revisar también cron y timers.
- **Escribir en rutas del sistema.** Usar directorios de trabajo propios y limpiar al terminar cuando el CTF lo exija.
- **Subestimar Defender/EDR.** winPEAS y mimikatz son detectables; preferir enumeración manual y no desactivar protecciones sin autorización.
- **Usar credenciales fuera de alcance.** Reutilizar credenciales encontradas solo dentro del objetivo permitido.
- **Ignorar la arquitectura.** Usar binarios x64 en sistemas x86 o versiones desactualizadas de GodPotato/PrintSpoofer da errores silenciosos.
- **Confundir la versión de la técnica con la del SO.** Las fichas de GodPotato y PrintSpoofer indican rangos de versiones; comprobar `systeminfo` antes de elegir.
- **Dar por buena una fuente secundaria.** Los snippets de búsqueda no sustituyen al README ni a la documentación oficial.

## Fuentes

Fuentes verificadas directamente [V]:
- [PEASS-ng (linPEAS/winPEAS)](https://github.com/peass-ng/PEASS-ng) [V]
- [pspy (DominicBreuker)](https://github.com/DominicBreuker/pspy) [V] — flags `-p`, `-f`, `-i`, `-r` y funcionamiento con procfs/inotify.
- [GTFOBins](https://gtfobins.org/) [V] — contextos Unprivileged, Sudo, SUID, Capabilities.
- [LOLBAS Project](https://lolbas-project.github.io/) [V] — categorías y funciones.
- [Microsoft Learn: Privilege Constants (Winnt.h)](https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants) [V] — descripción de SeImpersonate, SeBackup, SeRestore, SeDebug, SeTakeOwnership, SeLoadDriver.
- [GodPotato (BeichenDream)](https://github.com/BeichenDream/GodPotato) [V] — técnica y versiones según README.
- [PrintSpoofer (itm4n)](https://github.com/itm4n/PrintSpoofer) [V] — técnica y versiones según README.
- [mimikatz (gentilkiwi)](https://github.com/gentilkiwi/mimikatz) [V] — funciones y advertencia de uso del autor.
- [BloodHound (SpecterOps)](https://bloodhound.specterops.io/) [V parcial] — la página consultada describe solo la edición Enterprise.

Fuentes no verificadas directamente [NV] (obtenidas de búsquedas o secundarias):
- [HackTricks, Windows local privilege escalation](https://book.hacktricks.xyz/windows-hardening/windows-local-privilege-escalation) [NV] — AlwaysInstallElevated y SeImpersonate (solo snippets).
- [HackTricks, Linux privilege escalation](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html) [NV] — la página devolvió HTTP 402 (no leída).
- [MITRE ATT&CK, S0521 (BloodHound)](https://attack.mitre.org/software/S0521/) [NV].
- [Windows Installer policy](https://learn.microsoft.com/en-us/windows/win32/msi/windows-installer-policy-settings) [NV] — la URL devolvió 404; la política AlwaysInstallElevated sigue sin verificarse en fuente primaria.
- [Kali: peass-ng](https://www.kali.org/tools/peass-ng/) [NV] — variantes de linPEAS/winPEAS.

## Relación con otros planes

- **Planes de explotación inicial** (`analisis/` de CVEs y web/pwn): este plan empieza cuando ya hay acceso. Si el acceso inicial vino de una vulnerabilidad, el exploit de kernel de este plan debe coordinarse con el plan de explotación.
- **Plan de red / pivoting:** movimiento lateral y túneles (Ligolo-ng, chisel) se tratan allí; este plan solo recoge el punto de partida.
- **Plan de criptografía y cracking:** hashes obtenidos con mimikatz o de `/etc/shadow` se procesan con el plan de cripto/credenciales.
- **Plan forense/stego:** si la bandera está oculta en ficheros o imágenes, se deriva al plan correspondiente.
- **Plan de directorio activo (si existe):** rutas de ataque de BloodHound y Kerberos se desarrollan en su plan específico.
- **Plan de reconocimiento (OSINT / red):** reutilizar la lista de servicios y puertos ya descubiertos para no repetir el escaneo.

## Autorización

- Este plan es **metodología genérica**. No autoriza ni ejecuta acciones sobre ningún objetivo.
- Toda ejecución requiere que el objetivo figure en un `ctf/SCOPE.md` confirmado, con fase de post-explotación permitida. Actualmente **no existe** `ctf/SCOPE.md` en el repositorio, por lo que ninguna acción está autorizada todavía.
- Las acciones de escalada, extracción de credenciales y movimiento lateral se limitan a los hosts del alcance.
- **Propuesta pendiente de aprobación:** (1) confirmar el alcance del CTF en `ctf/SCOPE.md`; (2) aprobar si se permite el uso de herramientas ruidosas (winPEAS, mimikatz, exploits de kernel) o solo enumeración manual; (3) decidir si el movimiento lateral está incluido en el alcance.
- La ejecución real la realiza Codex dentro del alcance aprobado; este documento no contiene código ejecutable para ningún objetivo.
