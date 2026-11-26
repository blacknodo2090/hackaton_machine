# Plan de análisis 10 — Configuración y hardening

- **Punto de vista:** Buscar fallos de configuración explotables en un objetivo autorizado: credenciales por defecto, permisos laxos, cabeceras de seguridad ausentes, CORS mal configurado, TLS débil, servicios y paneles expuestos, listados de directorios, secretos en configuración o en el repositorio, y backups o archivos temporales olvidados.
- **Cuándo aplicarlo:** Cuando el reconocimiento (planes 01, 02, 03 y 07) ya ha identificado servicios web, APIs, repositorios o equipos dentro del alcance confirmado, y se quiere convertir la superficie en hallazgos concretos y explotables. Es el paso previo a los planes de explotación de cada servicio.

> Estado: propuesta pendiente de aprobación del usuario. Las etiquetas **[verificado]** y **[no verificado]** indican si el dato se comprobó en la documentación consultada para este plan.

## Preparación

1. **Alcance:** confirmar que el objetivo figura en `ctf/SCOPE.md` confirmado. Sin ese archivo, no se ejecuta ningún comando de este plan.
2. **Lista de activos:** crear una lista de hosts, URLs y rutas permitidas (por ejemplo `ctf/objetivos-permitidos.txt`), una por línea, para que las herramientas no salgan del alcance.
3. **Límites de ritmo:** fijar tasas bajas (nuclei `-rl`, nikto con tuning limitado) para no provocar denegación de servicio. Ninguna prueba de este plan incluye fuerza bruta.
4. **Carpeta de evidencias fuera del control de versiones:** usar una ruta como `ctf/evidencias/10-config/`, añadida a `.gitignore`. Los resultados de escáneres de secretos contienen credenciales reales; no deben quedar en archivos versionados. Redactar en los informes (`--redact` en gitleaks).
5. **Línea base de cada objetivo:** registrar fecha, IP/host, puertos ya conocidos (plan 03) y tecnologías detectadas. Así se distingue un hallazgo nuevo de uno heredado.
6. **Acceso al código o a los artefactos (si aplica):** si el alcance incluye un repositorio o una imagen, clonarlo con `git clone --mirror` en la carpeta de evidencias para no modificar el original.

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| `curl` (`curl.exe`) | Cabeceras HTTP, CORS, métodos, rutas expuestas, verificación manual de configuraciones. Ya viene en Windows 10/11. | Nativo Windows (`curl.exe`). Kali/WSL también. |
| `openssl s_client` | Comprobar versiones TLS, cadena de certificados y cifrados a mano. | Windows con OpenSSL (p. ej. el incluido en Git for Windows) [no verificado]. Kali/WSL: nativo. |
| [nuclei](https://github.com/projectdiscovery/nuclei) | Plantillas YAML para configuraciones erróneas, exposiciones y paneles. Se puede filtrar por etiquetas y severidad. | Instalable con Go (`go install`) [verificado]. Binario oficial para Windows: no confirmado en las fuentes consultadas [no verificado]. |
| [testssl.sh](https://github.com/testssl/testssl.sh) | Auditoría TLS completa: protocolos, cifrados, vulnerabilidades conocidas (Heartbleed, etc.), cabeceras. | Solo con WSL2, MSYS2 o Cygwin [verificado]. Kali/WSL recomendado. |
| [nikto](https://github.com/sullo/nikto) | Escáner de servidor web (Perl): configuraciones por defecto, archivos peligrosos, cabeceras, listados de directorios. Muy ruidoso. | Requiere Perl. Kali/WSL recomendado; Windows con Perl no verificado [no verificado]. |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Busca secretos en el historial de git (`git`) o en un directorio (`dir`). Permite informes JSON/SARIF y redacción. | Binario en releases y Docker [verificado]; binario para Windows no confirmado en la página consultada [no verificado]. Kali/WSL: nativo. |
| [trufflehog](https://github.com/trufflesecurity/trufflehog) | Busca secretos en git, sistemas de archivos y otras fuentes. Puede verificar si la credencial sigue activa (`--results=verified`). | Docker con PowerShell documentado [verificado]; binarios en releases. Kali/WSL: nativo. |
| [MDN HTTP Observatory](https://developer.mozilla.org/en-US/observatory) | Evaluación de cabeceras de seguridad (HSTS, CSP, CORP, Referrer-Policy, cookies) con puntuación de A+ a F. Pensado para sitios web. | Web o API v2 (`POST https://observatory-api.mdn.mozilla.net/api/v2/scan?host=<dominio>`) [verificado]. Alternativa: securityheaders.com [no verificado]. |
| PowerShell (`Get-ChildItem`, `icacls`) | Buscar copias y archivos temporales en Windows, revisar permisos NTFS. | Nativo Windows. |
| `find`, `ls -la`, `stat` | Buscar archivos con permisos de escritura para otros, copias y archivos ocultos. | Kali/WSL. |
| `rg` (ripgrep) | Buscar patrones de contraseñas y claves en configuraciones y en código. | Nativo Windows (instalable) y Kali/WSL. |

## Procedimiento paso a paso

Los comandos usan marcadores: `OBJETIVO` (host o URL dentro del alcance), `RUTA` (copia local del repositorio o carpeta) y `EVID` (carpeta de evidencias). Antes de ejecutar, revisar la ayuda local con `--help`, porque las opciones pueden cambiar entre versiones.

**1. Verificar el alcance**
Confirmar que `OBJETIVO` está en `ctf/SCOPE.md` y en la lista de activos permitidos. Si no está, parar.

**2. Cabeceras HTTP básicas (Windows: `curl.exe`)**
```powershell
curl.exe -sI https://OBJETIVO/ > EVID\cabeceras.txt
```
Solicita solo las cabeceras de respuesta. Revisar la presencia de `Strict-Transport-Security`, `Content-Security-Policy`, `X-Content-Type-Options`, `Referrer-Policy`, `frame-ancestors` (o `X-Frame-Options`) y la ausencia de cabeceras que revelen versiones (`Server`, `X-Powered-By`).

**3. Redirección HTTP a HTTPS y cookies**
```powershell
curl.exe -sI http://OBJETIVO/
curl.exe -sI https://OBJETIVO/ | findstr /i "set-cookie"
```
La primera comprueba si el HTTP redirige a HTTPS en el mismo host. La segunda muestra las cookies: buscar ausencia de `Secure`, `HttpOnly` o `SameSite`.

**4. Métodos HTTP habilitados**
```powershell
curl.exe -i -X OPTIONS https://OBJETIVO/
curl.exe -i -X TRACE https://OBJETIVO/
```
Busca `PUT`, `DELETE`, `TRACE` o `CONNECT` en `Allow` o en la respuesta. Son candidatos a hallazgo, no prueba de explotación por sí mismos.

**5. CORS: reflejo del origen**
```powershell
curl.exe -sI -H "Origin: https://origen-ajeno.example" https://OBJETIVO/api/usuario
```
Si `Access-Control-Allow-Origin` devuelve el mismo origen enviado y `Access-Control-Allow-Credentials: true`, hay CORS reflejado con credenciales. Probar también `Origin: null` y variantes de sufijo/prefijo del dominio. Dominio de ejemplo: `origen-ajeno.example`, de uso reservado.

**6. Rutas típicas expuestas (comprobación manual, lista corta)**
```powershell
foreach ($r in @("/.git/HEAD","/.env","/.svn/entries","/backup.zip","/server-status","/phpinfo.php","/actuator/env","/.DS_Store","/robots.txt")) {
  "{0} {1}" -f (curl.exe -s -o NUL -w "%{http_code}" "https://OBJETIVO$r"), $r
}
```
Un `200` (o un `403` que revela que el recurso existe) en rutas de desarrollo o de backup es un indicador. Ampliar la lista solo con rutas del propio alcance. Una lista amplia de rutas la cubre nuclei (paso 9).

**7. Listado de directorios**
```powershell
curl.exe -s https://OBJETIVO/imagenes/ | findstr /i "Index of"
```
La página "Index of" indica listado abierto. Repetir en directorios que aparezcan en el paso 6 o en el mapa del sitio.

**8. TLS con testssl.sh (Kali o WSL)**
```bash
./testssl.sh --protocols --vulnerable --headers --jsonfile EVID/testssl.json https://OBJETIVO:443
```
- `--protocols`: versiones TLS aceptadas (SSLv3, TLS 1.0 y 1.1 son hallazgos).
- `--vulnerable`: comprobaciones de vulnerabilidades conocidas.
- `--headers`: cabeceras de seguridad.
- `--jsonfile`: salida JSON para el informe.
Las opciones se confirman con `./testssl.sh --help` y con la página de manual [verificado: el proyecto documenta salida JSON/CSV y el manual; los nombres exactos de opciones se deben comprobar con `--help`].

Comprobación rápida de una versión concreta con OpenSSL:
```bash
openssl s_client -connect OBJETIVO:443 -tls1 < /dev/null
```
Si conecta, TLS 1.0 está aceptado. OpenSSL moderno puede tener TLS 1.0 deshabilitado a nivel de compilación; un fallo no siempre prueba que el servidor esté bien configurado [no verificado].

**9. Plantillas de configuración con nuclei**
```powershell
nuclei -u https://OBJETIVO -tags misconfig,exposure,default-login -severity low,medium,high,critical -rl 50 -jsonl -o EVID\nuclei.jsonl
```
- `-u`: objetivo.
- `-tags`: ejecuta plantillas por etiqueta (`misconfig` y `exposure` están en el repositorio de plantillas oficial).
- `-severity`: filtra por severidad.
- `-rl`: limita las peticiones por segundo (por defecto 150).
- `-jsonl -o`: salida JSONL en archivo.
Usar `-tags` con etiquetas de la lista del repositorio de plantillas, y revisar las plantillas `default-login` antes de ejecutarlas, porque intentan accesos. Las etiquetas se comprueban con `nuclei -tl` (lista de plantillas).

**10. Escáner web complementario con nikto (Kali o WSL)**
```bash
perl nikto.pl -h https://OBJETIVO -ssl -Tuning 23 -o EVID/nikto.json -Format json
```
- `-h`: host o URL.
- `-ssl`: fuerza SSL en el puerto indicado.
- `-Tuning 23`: categorías de configuración errónea (2) y divulgación de información (3). Los códigos completos están en la documentación de cirt.net.
- `-o` y `-Format json`: salida en JSON.
Nikto es ruidoso y puede disparar alertas. Usarlo solo con autorización explícita del alcance y con un único objetivo.

**11. Secretos en configuración y código (copia local)**
```powershell
rg -n -i "password|passwd|secret|api[_-]?key|token|BEGIN (RSA|OPENSSH|EC) PRIVATE" RUTA > EVID\rg-secretos.txt
```
Busca patrones en configuración y código. Revisar los resultados a mano para descartar falsos positivos.

**12. Secretos en el historial de git con gitleaks**
```bash
gitleaks git RUTA -f json -r EVID/gitleaks.json --redact
```
- `git`: analiza el historial (`git log -p`).
- `-f json -r`: formato y archivo de informe.
- `--redact`: oculta el secreto en la salida por consola.
Para una carpeta sin historial: `gitleaks dir RUTA -f json -r EVID/gitleaks-dir.json --redact`. Los comandos `detect` y `protect` quedaron obsoletos desde la versión 8.19.0 [verificado].

**13. Verificación de credenciales con trufflehog**
```bash
trufflehog git file://RUTA --results=verified,unknown --json > EVID/trufflehog.json
```
Solo `verified` muestra las credenciales confirmadas como activas. `unknown` incluye las que no se pudieron verificar por error. Para archivos y carpetas: `trufflehog filesystem RUTA`. Nota: la verificación contacta al proveedor del servicio; confirmar que está permitido por el alcance antes de usarla [verificado: la documentación describe la verificación activa; la ruta `file://` en Windows no está confirmada].

**14. Permisos y archivos olvidados en Windows (PowerShell)**
```powershell
Get-ChildItem -Recurse -Force -Path RUTA -Include *.bak,*.old,*.orig,*.swp,*.tmp,*.zip,*.tar.gz,*.sql,*.log,.env,web.config.bak |
  Select-Object FullName, Length, LastWriteTime
icacls RUTA\config /T
```
La primera lista copias, temporales y configuraciones abandonadas. La segunda muestra las ACL: buscar grupos como `Everyone`, `Users` o `Authenticated Users` con permisos de escritura (`(W)`, `(M)` o `(F)`).

**15. Permisos y archivos olvidados en Linux (Kali o WSL)**
```bash
find RUTA -xdev \( -perm -o+w -o -name "*.bak" -o -name "*.old" -o -name "*~" -o -name ".env" \) -ls
```
Busca archivos con escritura para otros usuarios, copias y ficheros de entorno.

**16. Cabeceras con MDN HTTP Observatory**
```bash
curl -s -X POST "https://observatory-api.mdn.mozilla.net/api/v2/scan?host=OBJETIVO" > EVID/observatory.json
```
Devuelve una puntuación y las pruebas superadas o fallidas. **Limitación:** la consulta envía el nombre del host a un tercero (Mozilla). Solo usarla si el nombre del objetivo puede revelarse; si no, usar el paso 2 y securityheaders.com solo si se autoriza lo mismo.

**17. Consolidación**
Unir los resultados en una tabla con: activo, hallazgo, severidad, evidencia (ruta al archivo de `EVID`), comando que lo produjo, y estado (`confirmado` o `pendiente de comprobar`). No incluir secretos completos en el informe; citar solo el inicio y la ubicación.

## Qué buscar (indicadores de vulnerabilidad)

- **Cabeceras:** ausencia de HSTS, CSP o `frame-ancestors` (o `X-Frame-Options`), `X-Content-Type-Options`, o de `Referrer-Policy`. El MDN Observatory cubre CSP, HSTS, CORP y Referrer-Policy [verificado]. Una cabecera ausente no siempre es explotable: priorizar la que habilita un ataque concreto en el objetivo.
- **CORS:** `Access-Control-Allow-Origin` que refleja cualquier origen, combinado con `Allow-Credentials: true`; o `null` permitido.
- **Métodos:** `PUT`, `DELETE`, `TRACE` habilitados en rutas sensibles.
- **Rutas y paneles:** `/.git/`, `/.env`, `/.svn/`, copias `.bak`/`.old`/`.zip`, paneles de administración, páginas de estado o de información (`server-status`, `phpinfo`, endpoints de actuator o similares) accesibles sin autenticación.
- **Listados:** respuestas con "Index of" o equivalentes en directorios de subida, de imágenes o de copias.
- **TLS:** SSLv3, TLS 1.0/1.1, cifrados débiles, certificados caducados o autofirmados en servicios públicos, falta de HSTS.
- **Credenciales:** cuentas por defecto documentadas por el fabricante, usuarios de prueba o contraseñas de ejemplo en `README` o en páginas de instalación (comprobar a mano, sin fuerza bruta).
- **Secretos:** claves de API, tokens, cadenas de conexión, claves privadas en archivos de configuración, en `.env`, en el historial de git (incluso si ya no aparecen en el código actual) o en copias de seguridad.
- **Permisos:** escritura para `Everyone`/`Users` en directorios de aplicación o de servicio; archivos de configuración legibles por cualquiera.

## Cómo interpretar y pasar a explotación

1. **Clasificar:** cada hallazgo se trata como *indicio* hasta reproducirse con una petición o comando concreto. Anotar la evidencia exacta (cabecera, código HTTP, línea de configuración).
2. **Priorizar por impacto:** secretos válidos y rutas que devuelven código fuente o copias de la base de datos son prioritarios. Una cabecera ausente sin efecto práctico queda como hallazgo menor.
3. **Pasar a explotación (propuestas, no ejecutadas):**
   - **Secretos válidos:** usar el secreto contra el servicio que lo emite, solo para comprobar acceso y con el mínimo de acciones; registrar el alcance del acceso. Derivar al plan de servicios correspondiente.
   - **`.git` expuesto:** reconstruir el repositorio a partir de los objetos descargados y revisar el historial con gitleaks (paso 12). Herramienta concreta [no verificado en esta investigación]: buscar en writeups de CTF antes de elegirla.
   - **CORS reflejado con credenciales:** construir una página de prueba que lea una respuesta autenticada desde otro origen; verificar que la víctima de prueba es la propia cuenta del CTF.
   - **Backups o temporales:** descargarlos y buscar credenciales, código y hashes; derivar al plan de bases de datos o de criptografía si procede.
   - **Panel por defecto:** probar las credenciales por defecto documentadas; no iterar contraseñas.
   - **TLS débil:** un fallo de TLS rara vez permite explotación directa en un CTF; usarlo como pista (por ejemplo, un servicio que acepta TLS 1.0 puede tener otra configuración antigua).
4. **Registrar cada paso** con el comando exacto y la salida, para poder reproducirlo.

## Errores comunes y trampas

- **Falsos positivos de nuclei y nikto:** una plantilla que coincide por texto puede marcar una página 200 genérica. Comprobar siempre a mano.
- **Ruido y bloqueos:** nikto y nuclei sin límite de ritmo pueden tumbar el servicio o activar bloqueos por IP. Usar `-rl` bajo y un solo host.
- **Plantillas de acceso:** las plantillas `default-login` y similares hacen intentos reales de autenticación; excluirlas si no están autorizadas.
- **Secretos reales en los informes:** guardar la salida de gitleaks o trufflehog sin `--redact` deja credenciales en el repositorio. Mantener `EVID` fuera de git.
- **Verificación activa de trufflehog:** `--results=verified` contacta al proveedor del secreto. Puede generar alertas en el proveedor o tocar sistemas fuera del alcance.
- **Confundir cabeceras de CDN o proxy:** la respuesta puede venir de un intermediario; comparar con la conexión directa al origen si está en el alcance.
- **Servicio distinto del esperado:** el mismo host puede responder distinto por HTTP/HTTPS, por puerto o por nombre (SNI). Probar con `-H "Host: ..."` solo dentro del alcance.
- **Historial de git:** eliminar un secreto de un commit no lo invalida; un secreto encontrado en el historial sigue siendo hallazgo.
- **Rutas de Windows:** en PowerShell, `curl` puede ser un alias de otra herramienta; usar `curl.exe`. En trufflehog, la ruta `file://` con letras de unidad puede requerir pruebas.
- **Supuestos de herramientas:** las opciones de testssl.sh, nikto y nuclei cambian entre versiones; comprobar con `--help` antes de copiar un comando.
- **Interpretar el puntaje:** un "A+" en el Observatory no garantiza ausencia de fallos; no cubre software desactualizado, SQL injection ni contraseñas.

## Fuentes

**Herramientas y documentación (oficiales)**
- nuclei (proyecto y comandos): https://github.com/projectdiscovery/nuclei [verificado: instalación con Go, flags `-u`, `-l`, `-t`, `-tags`, `-severity`, `-rl`, `-je`, `-jsonl`]
- Plantillas oficiales de nuclei (carpeta `misconfig`): https://github.com/projectdiscovery/nuclei-templates [verificado en búsqueda; cantidad de plantillas no confirmada]
- Guía de nuclei: https://projectdiscovery.io/blog/ultimate-nuclei-guide [citada en búsqueda; no abierta]
- testssl.sh: https://github.com/testssl/testssl.sh [verificado: plataformas, salida CSV/JSON/HTML]
- Página de manual de testssl.sh: https://manpages.debian.org/bookworm/testssl.sh/testssl.1.en.html [citada en búsqueda; no abierta]
- nikto (código y uso): https://github.com/sullo/nikto [verificado: instalación, `-h`, `-ssl`, `-Tuning`, `-o`, `-Format`]
- nikto, opciones de línea de comandos: https://cirt.net/nikto2-docs/options.html [citada; no abierta]
- gitleaks: https://github.com/gitleaks/gitleaks [verificado: comando `git`, `--report-format`, `--redact`, `detect` obsoleto desde 8.19.0]
- trufflehog: https://github.com/trufflesecurity/trufflehog [verificado: `git`, `filesystem`, `--results=verified,unknown`, Docker en PowerShell]
- MDN HTTP Observatory, preguntas frecuentes: https://developer.mozilla.org/en-US/observatory/docs/faq [verificado: qué comprueba, uso web/API, endpoint v2]
- MDN HTTP Observatory, anuncio: https://developer.mozilla.org/en-US/blog/mdn-http-observatory-launch [citado; no abierto]

**Metodología**
- OWASP Web Security Testing Guide, sección 6 (Configuración y despliegue): https://wstg.owasp.org/latest/06-Configuration_and_Deployment_Management/ [verificado: lista de pruebas 6.1 a 6.14, que incluye infraestructura, HTTP methods, HSTS, permisos de archivos, backups, CSP, cloud storage]
- HackTricks (libro de metodología y servicios): https://book.hacktricks.xyz [no verificado: se consultó un espejo, no la fuente principal]
- Metodología de pentesting (espejo de HackTricks): https://angelica.gitbook.io/hacktricks/generic-methodologies-and-resources/pentesting-methodology [espejo; no verificado como fuente primaria]

**Alternativas no verificadas en detalle**
- securityheaders.com: mencionado como alternativa al Observatory [no verificado directamente].

## Relación con otros planes

- `01-fisico-hardware.md`: alcance y reconocimiento inicial; este plan empieza cuando el alcance está confirmado.
- `02-red-conexiones.md`: conexiones y servicios expuestos; los hosts y puertos que salen de allí son la entrada de este plan.
- `03-puertos-servicios.md`: versiones y servicios por puerto; cuando un servicio web aparece allí, se aplican los pasos 2 a 10 de este plan.
- `05-bases-datos-consultas.md`: destino de credenciales de base de datos y de copias `.sql` encontradas aquí.
- `07-osint-reconocimiento.md`: origen de nombres de dominio, repositorios públicos y fugas de secretos en fuentes abiertas, que complementan los pasos 11 a 13.
- `08-ingenieria-social.md`: uso de credenciales por defecto o de cuentas descubiertas en contextos humanos; fuera del alcance técnico de este plan.
- Planes de servicios web, criptografía/forense y pivoting (nombres por definir en la biblioteca): destino de los hallazgos según el tipo de fallo.

Nota: los planes de servicios web, criptografía/forense y pivoting aún no existen en `analisis/`; los nombres son propuestas pendientes de aprobación.

## Autorización

- Es metodología; aplícala a un objetivo solo si figura en un `ctf/SCOPE.md` confirmado.
- Ninguna prueba de este plan incluye denegación de servicio, fuerza bruta ni acceso a datos fuera del alcance.
- La verificación activa de secretos (trufflehog con `verified`) y el envío de un host a servicios de terceros (MDN Observatory) requieren confirmar que son aceptables para el alcance.
- Estado de este plan: propuesta pendiente de aprobación del usuario.
