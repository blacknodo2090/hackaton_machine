# Plan de análisis 09 — Autenticación y sesiones

- **Punto de vista:** examina cómo el objetivo decide quién eres y cuánto tiempo lo recuerda. Recorre el login, la gestión de sesión (cookies y tokens), los proveedores de identidad (OAuth, SAML), el segundo factor y el restablecimiento de contraseña. En un CTF, la mayoría de los fallos de autenticación no rompen la criptografía: se explotan por configuración (credenciales por defecto), por lógica (2FA o reset que se saltan), por validación incompleta (JWT que acepta `alg: none`) o por secretos débiles que se pueden crackear offline. Este plan separa lo que se prueba contra el servicio en línea (con límites) de lo que se hace offline sobre artefactos ya obtenidos.
- **Cuándo aplicarlo:** señales del reto:
  - Formulario de login, panel de administración o API con `Authorization: Bearer`.
  - Cookies o tokens con estructura reconocible: tres bloques separados por punto (JWT, empieza con `eyJ`), cookies de sesión largas o predecibles, o cookies que contienen datos legibles en base64.
  - Botones «Iniciar sesión con…», redirecciones a un proveedor externo, parámetros `state`, `code`, `redirect_uri`, o un `SAMLResponse` en POST.
  - Pantallas de código de verificación (2FA/OTP) o enlaces de restablecimiento de contraseña.
  - Hashes expuestos (volcados de base de datos, respuestas Kerberos, NTLM) que hay que crackear fuera de línea.

## Preparación
- **Autorización:** el objetivo debe figurar en un `ctf/SCOPE.md` confirmado antes de ejecutar nada. Este plan es solo metodología.
- **Límites de intentos:** antes de cualquier fuerza bruta o spraying, revisa en el alcance del reto cuántos intentos se permiten, si hay bloqueo de cuenta y cuál es la ventana de bloqueo. Un bloqueo mal gestionado puede afectar a otros participantes, y el reto puede prohibir la fuerza bruta.
- **Entorno de trabajo:**
  - Carpeta de trabajo en el scratchpad: `req.txt`, `users.txt`, `pass.txt`, `jwt.txt`. No guardes credenciales ni tokens en el repositorio.
  - Un proxy (Burp Suite o equivalente) para capturar la petición de login y las cookies de referencia.
- **Línea base:** antes de atacar, anota la respuesta de un login incorrecto y de uno correcto (código HTTP, longitud, cabeceras `Set-Cookie`, redirección `Location`, mensaje de error). Sin esa línea base no distingues un fallo de un éxito.
- **Estado de las fuentes:** PortSwigger (JWT, autenticación, OAuth) se consultó con éxito. La página SAML de Web Security Academy devolvió 404; el contenido SAML se toma de los artículos de investigación de PortSwigger y está marcado como tal. HackTricks devolvió HTTP 402 en sesiones anteriores y no se usa como evidencia.

## Herramientas
| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| curl.exe | Peticiones de login, control de cookies (`-c`/`-b`) y cabeceras | Windows: sí (incluido). Kali/WSL: sí |
| Burp Suite (Repeater, Intruder, extensión SAML Raider) | Capturar y modificar logins, JWT y SAML; fuerza bruta controlada | Ambos (SAML Raider: extensión de Burp, según fuente de terceros) |
| hydra | Fuerza bruta en formularios web (`http-post-form`), SSH, FTP, SMB, etc. | Windows: no nativo (usar WSL). Kali/WSL: sí. Módulos verificados en el README |
| medusa | Alternativa a hydra para fuerza bruta en paralelo | Windows: no nativo. Kali/WSL: sí (**no verificado en esta sesión**) |
| NetExec (`nxc`) | Password spraying y validación de credenciales en SMB, LDAP, SSH, etc. Sucesor activo de CrackMapExec | Windows: no recomendado, usar WSL/Kali (**no verificado**). Kali/WSL: sí |
| CrackMapExec | Histórico; el proyecto ya no se mantiene. Usar NetExec | Ver NetExec |
| hashcat | Crackeo offline de hashes (MD5, NTLM, bcrypt, JWT HMAC, Kerberos) con GPU | Windows: sí (binario oficial). Kali/WSL: sí (GPU en WSL es limitada, no verificado) |
| john (John the Ripper, versión jumbo) | Crackeo offline con formatos automáticos, reglas e incremental | Windows: sí (binarios de comunidad, no verificado). Kali/WSL: sí |
| jwt_tool | Analizar, manipular y atacar JWT (alg none, kid, jku, jwk, confusión de claves) | Windows: con Python 3.6+ (no verificado en esta sesión); el proyecto recomienda Docker. Kali/WSL: sí |
| PowerShell | Decodificar JWT en local sin herramientas (ver paso 7) | Windows: sí (nativo) |
| openssl | Generar claves y firmas HMAC/RSA de prueba | Windows: sí (vía Git for Windows o instalador). Kali/WSL: sí |

> **Catálogo Kali:** ver [KALI_CATALOG.md](../docs/tools/KALI_CATALOG.md) → Credential Access · Initial Access.

## Procedimiento paso a paso

1. **Mapear el mecanismo de autenticación.** Captura el flujo completo: login, redirecciones, cookies emitidas, token devuelto y cómo se envía en peticiones siguientes.
   ```powershell
   curl.exe -s -i -c jar.txt -X POST "http://OBJETIVO/login" -d "user=USUARIO&pass=CLAVE_INCORRECTA" -o resp_fail.txt
   curl.exe -s -i -c jar.txt -X POST "http://OBJETIVO/login" -d "user=USUARIO&pass=CLAVE_CORRECTA" -o resp_ok.txt
   ```
   `-c jar.txt` guarda las cookies emitidas; `-i` incluye cabeceras y `Set-Cookie`. Compara `resp_fail.txt` y `resp_ok.txt` (código, longitud, mensaje). Usa únicamente credenciales que el reto proporcione o que sean de prueba.

2. **Enumeración de usuarios por diferencias.** Si el mensaje o el tiempo de respuesta cambia entre «usuario inexistente» y «contraseña incorrecta», el nombre de usuario es válido. PortSwigger lo describe como paso previo a la fuerza bruta (fuente: Authentication, sección de enumeración de usuarios).
   ```powershell
   curl.exe -s -X POST "http://OBJETIVO/login" -d "user=noexiste_xyz&pass=x" -o a.txt
   curl.exe -s -X POST "http://OBJETIVO/login" -d "user=admin&pass=x" -o b.txt
   fc.exe /b a.txt b.txt
   ```
   Si `fc` encuentra diferencias, el mensaje distingue usuarios. Para tiempos, mide con `Measure-Command { curl.exe -s ... }`.

3. **Credenciales por defecto.** Prueba solo las parejas conocidas del fabricante o del software identificado (p. ej. `admin:admin`, `admin:password`, las de la documentación del producto). Son de bajo ruido: una o dos peticiones por cuenta. Documenta el producto y la fuente de las credenciales (listas públicas de defaults en repositorios de la comunidad: **no verificado en esta sesión**).
   ```powershell
   curl.exe -s -i -c jar.txt -X POST "http://OBJETIVO/login" -d "user=admin&pass=admin" -o def.txt
   ```

4. **Password spraying controlado.** Una contraseña común contra muchos usuarios, con pausa entre rondas para no bloquear cuentas. Usa listas de usuarios obtenidas en el paso 2 o en otros planes (LDAP, OSINT).
   ```bash
   nxc smb OBJETIVO -u users.txt -p 'Summer2026!' --continue-on-success
   nxc smb OBJETIVO -u users.txt -p passwords.txt --no-bruteforce
   ```
   - `--continue-on-success` sigue probando tras un acierto. Sin este flag, nxc se detiene al primer login válido (fuente: NetExec wiki, password spraying).
   - `--no-bruteforce` empareja usuario y contraseña línea a línea en vez de probar todas las combinaciones (fuente: hackviser, NetExec).
   - Para revisar la política de bloqueo antes de spraying, existe la opción `--pass-pol` en nxc (**no verificado en esta sesión**).

5. **Fuerza bruta de formulario con hydra.** Solo con permiso del reto y con un número limitado de intentos. La sintaxis `http-post-form` es `ruta:parámetros:F=texto_de_fallo` (o `S=` para éxito), con `^USER^` y `^PASS^` como marcadores (fuente: tutoriales recopilados en la búsqueda; el README oficial de hydra no detalla la sintaxis en la consulta realizada).
   ```bash
   hydra -L users.txt -P pass.txt -t 4 OBJETIVO http-post-form "/login:user=^USER^&pass=^PASS^:F=Usuario o contraseña incorrectos"
   hydra -l admin -P pass.txt -t 4 OBJETIVO https-post-form "/login:user=^USER^&pass=^PASS^:S=302"
   ```
   - `-t 4` limita las tareas paralelas. Un valor alto acelera pero puede tumbar el servicio (fuente: README de hydra).
   - `-L` y `-P` leen listas de usuarios y contraseñas; `-l` y `-p` aceptan un único valor (fuente: README de hydra).
   - `-f` (parar al primer acierto) y `-V` (salida detallada) existen en hydra pero **no se confirmaron en la consulta**; comprueba con `hydra -h`.
   - Para HTTPS, usa `https-post-form` (fuente: tutoriales; verificar con `hydra -U http-post-form`, que el README recomienda).

6. **Crackeo offline de hashes.** Identifica primero el tipo. Después elige modo.
   - **hashcat, modo por tipo** (verificado en la wiki de hashcat, example_hashes):

     | Tipo | `-m` |
     |---|---|
     | MD5 | 0 |
     | SHA-256 | 1400 |
     | NTLM | 1000 |
     | md5crypt (Unix) | 500 |
     | bcrypt `$2*$` | 3200 |
     | Kerberos 5 TGS-REP etype 23 (Kerberoast) | 13100 |
     | NetNTLMv2 | 5600 |
     | JWT (HS256 en la página) | 16500 |

   - **Ataque por diccionario:**
     ```powershell
     hashcat -m 1000 -a 0 hashes.txt rockyou.txt
     ```
     `-a 0` es el modo diccionario (**ataque y sintaxis según documentación oficial de hashcat, no verificada en esta sesión**).
   - **Diccionario con reglas:** `hashcat -m 1000 -a 0 hashes.txt rockyou.txt -r rules\best64.rule` (**no verificado en esta sesión**; la regla `best64.rule` viene con hashcat).
   - **Máscara (fuerza bruta acotada):** `hashcat -m 0 -a 3 hashes.txt ?u?l?l?l?d?d?d?d` (**no verificado en esta sesión**; `-a 3` es el modo máscara).
   - **Ver resultados:** `hashcat -m 1000 hashes.txt --show`.
   - **john, formato explícito:**
     ```bash
     john --format=raw-md5 --wordlist=rockyou.txt hashes.txt
     john --wordlist=rockyou.txt --rules hashes.txt
     john --incremental hashes.txt
     john --show hashes.txt
     ```
     - `--format=NAME` fuerza el tipo en vez de autodetectar. Admite comas, comodines y exclusiones (fuente: documentación OPTIONS de john jumbo).
     - `--wordlist` activa el modo diccionario, `--rules` aplica mutaciones, `--incremental` fuerza bruta, `--show` lista lo crackeado (fuente: documentación EXAMPLES y OPTIONS de john jumbo).
     - `raw-md5` y `nt` aparecen en la documentación de jumbo; el nombre exacto del formato para cada hash debe comprobarse con `john --list=formats` (**no verificado en esta sesión**).
   - Guarda la sesión con `--session=NAME` si el crackeo será largo (fuente: OPTIONS de john).

7. **Analizar un JWT.** Decodifica las dos primeras partes (cabecera y payload) en base64url. Sin verificar la firma, lo que lees es lo que el servidor interpreta.
   ```powershell
   function B64Url($s){ $s=$s.Replace('-','+').Replace('_','/'); switch($s.Length%4){2{$s+='=='} 3{$s+='='}}; [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }
   $t = (Get-Content jwt.txt).Trim().Split('.')
   B64Url $t[0]   # cabecera: alg, kid, jku, jwk
   B64Url $t[1]   # payload: sub, role, exp
   ```
   Decodificar en local evita enviar el token a servicios externos. La función es un borrador de este plan y **no se ha ejecutado en esta sesión**.

8. **Comprobar la verificación de firma.** Prueba cambios sencillos y observa si el servidor los acepta.
   - **alg=none (sin firma):** cambia `alg` a `none` (y variantes `None`, `NONE`), modifica el payload y deja la firma vacía, con el punto final. PortSwigger describe que el servidor acepta el token sin firma (fuente: PortSwigger JWT attacks, sección alg none). Con jwt_tool:
     ```bash
     python3 jwt_tool.py TOKEN -X a
     ```
   - **Modificar claims con firma sin verificar:** con `-I` (inyección/manipulación) y `-pc`/`-pv` (nombre y valor de un claim del payload):
     ```bash
     python3 jwt_tool.py TOKEN -I -pc role -pv admin
     ```
     PortSwigger describe el caso «firma no verificada» en su laboratorio correspondiente (fuente: PortSwigger JWT, lab «unverified signature»).
   - **Reproducir la petición con el token modificado:** `curl.exe -s -i -H "Authorization: Bearer NUEVO_TOKEN" http://OBJETIVO/api/yo`.

9. **Secreto débil en HS256.** Si la firma es HMAC, intenta recuperar el secreto offline con hashcat (modo 16500, verificado) y luego firma un token nuevo.
   ```powershell
   hashcat -m 16500 -a 0 jwt.txt rockyou.txt
   ```
   `jwt.txt` contiene el token completo. PortSwigger usa `hashcat -a 0 -m 16500 <jwt> <wordlist>` en su laboratorio de secreto débil (fuente: PortSwigger JWT, weak signing key). El laboratorio usa el secreto `secret1`. Para firmar con el secreto recuperado, jwt_tool permite `-S` con la clave (**opción no confirmada en esta sesión**; comprobar con `python3 jwt_tool.py -h`).

10. **Cabeceras de confianza del JWT: kid, jku, jwk.** Revisa si el token trae cabeceras que indican de dónde saca la clave el servidor.
    - **kid:** puede ser una ruta de archivo o una consulta SQL. PortSwigger indica que, con path traversal, se puede apuntar a un archivo predecible como `/dev/null` cuyo contenido vacío permite firmar con cadena vacía (fuente: PortSwigger JWT, kid). Con jwt_tool: `-hc kid -hv "../../../../dev/null"` (**`-hc`/`-hv` verificados en el README; el valor de ejemplo viene de la fuente de PortSwigger y no se ha probado en un laboratorio**).
    - **jku:** el servidor descarga un JWK Set desde una URL. PortSwigger indica que, si no valida el dominio, puede apuntarse a un JWK Set propio. Con jwt_tool: `-X i` para inyección JWKS (fuente: README de jwt_tool, sección de opciones de explotación).
    - **jwk embebido:** el servidor acepta una clave pública incrustada en la cabecera. PortSwigger describe firmar con la clave privada correspondiente y embeber la pública.

11. **Confusión de algoritmos RS256 → HS256.** Si el servidor usa RSA pero acepta HS256, firma el token con HMAC usando la clave pública como secreto. PortSwigger describe el procedimiento: obtener la clave pública, cambiar el algoritmo a HS256 y firmar con esa clave (fuente: PortSwigger JWT, algorithm confusion). Con jwt_tool, la clave pública se pasa con `-V -pk` para verificar, y la firma con `-X k` (**`-X k` no verificado en esta sesión**). El formato exacto de la clave (PEM con o sin salto de línea final) afecta al resultado; prueba variantes.

12. **Cookies y sesiones.** Revisa las cabeceras `Set-Cookie`. Busca `HttpOnly`, `Secure` y `SameSite` ausentes, valores cortos o predecibles, y que la sesión no cambie tras el login (fijación de sesión). Decodifica la cookie si es base64 o contiene JSON.
    ```powershell
    curl.exe -s -i -c jar.txt -X POST "http://OBJETIVO/login" -d "user=USUARIO&pass=CLAVE"
    type jar.txt
    curl.exe -s -i -b jar.txt "http://OBJETIVO/cuenta"
    ```
    Compara el valor de la cookie antes y después de autenticarte. Si cambia, bien; si no, revisa fijación.

13. **OAuth 2.0.** Revisa el flujo de autorización. PortSwigger identifica estos fallos (fuente: PortSwigger OAuth):
    - `state` ausente o predecible: permite login CSRF, vinculando la cuenta de la víctima a la del atacante.
    - `redirect_uri` mal validado: el código o token llega a un destino controlado. Pruebas típicas: recorrido de directorios, parámetros duplicados, ambigüedad de `localhost`.
    - `scope` no comparado con el original en el intercambio de código.
    - En flujo implícito, datos enviados por el cliente que no se comparan con el token.
    - Registro de cuenta sin verificar del email, que permite iniciar sesión como otra persona en el cliente.
    Prueba cambiando un valor de cada parámetro y observa si el servidor lo acepta. En la página consultada no aparece PKCE.

14. **SAML.** Decodifica el `SAMLResponse` (base64, a veces comprimido) y busca si la firma cubre la aserción completa. PortSwigger describe ataques de envoltura de firma XSW (XML Signature Wrapping) que explotan discrepancias entre el módulo de firma y el de aserción, y que bypassean la autenticación en bibliotecas SAML de código abierto (fuente: PortSwigger Research, «The Fragile Lock»). Para probar, la extensión de Burp SAML Raider automatiza las variantes XSW (fuente de terceros: redfoxsec; **no verificado en esta sesión**).

15. **2FA y restablecimiento de contraseña.** PortSwigger indica tres patrones (fuente: PortSwigger Authentication):
    - Se salta el paso 2 de la autenticación yendo directo a una página interna tras el primer factor.
    - La verificación del código no está atada a la sesión o a la cuenta: un código válido para un usuario sirve para otro.
    - El código de 4-6 dígitos se fuerza sin límite de intentos. Antes de probar, comprueba si hay bloqueo.
    - Restablecimiento: token predecible, token que no caduca, token que aparece en la respuesta o en la URL, o email que se envía a otro destinatario por manipulación de cabeceras.

16. **Documentar la cadena hasta la bandera.** Anota cada paso con la petición y la respuesta que lo demuestra (`req.txt`, `resp.txt`). Si la explotación requiere una acción que cambia estado (cambiar contraseña, cerrar sesiones), trátala como propuesta pendiente de aprobación.

## Qué buscar (indicadores de vulnerabilidad)
- **Credenciales:** `admin:admin` u otras parejas por defecto que funcionan; mensajes distintos entre usuario inexistente y contraseña incorrecta; tiempos de respuesta que varían con el usuario.
- **Fuerza bruta:** ausencia de bloqueo, límite de tasa o CAPTCHA tras múltiples fallos; el bloqueo se reinicia tras un acierto.
- **JWT:**
  - `alg: none` aceptado por el servidor.
  - Firma no verificada: el token modificado funciona sin firma válida.
  - Secreto HS256 que aparece en un diccionario (crackeable con hashcat modo 16500).
  - Cabeceras `kid`, `jku`, `jwk` aceptadas sin validar.
  - Algoritmo HS256 aceptado en un endpoint que espera RS256.
- **Cookies:** sin `HttpOnly`, `Secure` o `SameSite`; valores cortos, secuenciales o base64 de JSON sin firma; la sesión no se regenera tras el login.
- **OAuth:** `state` vacío o fijo; `redirect_uri` con coincidencia parcial; `scope` cambiable en el intercambio.
- **SAML:** firma que cubre solo el nodo `Signature` o un nodo distinto de la aserción; aserciones con varias copias.
- **2FA:** páginas internas accesibles sin completar el segundo factor; código no atado a la sesión; intentos ilimitados.
- **Reset:** token predecible, sin caducidad o no invalidado tras uso.
- **Hashes:** formatos débiles (MD5, NTLM, MD5crypt) crackeables con el diccionario del reto.

## Cómo interpretar y pasar a explotación
- **Credenciales válidas, sin importar cómo se obtuvieron** → sesión autenticada. Comprueba privilegios (cuenta de admin o de otro rol) con una petición a un recurso restringido. Esa petición es la prueba.
- **Token con `alg: none` aceptado o firma no verificada** → forja un token con el claim de privilegio y comprueba acceso a la zona restringida. Documenta el token y la petición.
- **Secreto HS256 recuperado** → firma un token nuevo con él, verifica que el servidor lo acepta y solo entonces sigue con los privilegios obtenidos.
- **Hash crackeado** → prueba la contraseña en el login y en otros servicios del reto (reutilización) solo si el alcance lo permite.
- **Spraying con acierto** → la cuenta válida es el punto de entrada. Para el siguiente paso, usa el plan de la capa de red o de aplicaciones que corresponda.
- **Fallo OAuth, SAML o 2FA** → confirma con una cuenta propia del reto antes de tocar cuentas ajenas; el objetivo es demostrar el bypass, no ampliar el acceso.
- Cualquier acción que cambie datos o estado es una propuesta pendiente de aprobación del usuario.

## Errores comunes y trampas
- **Sin línea base:** comparar solo «acierto» contra «fallo» sin guardar cabeceras y longitud lleva a falsos positivos (p. ej. redirecciones que son iguales en ambos casos).
- **Bloquear cuentas sin querer:** spraying sin pausa o con muchas rondas. Revisa la política antes.
- **Ignorar el `Content-Type`:** los formularios van en `application/x-www-form-urlencoded`, el JSON en `application/json`. Un `Content-Type` incorrecto devuelve un error que parece fallo del login.
- **Escapes en PowerShell:** los `&` y las comillas dentro de `-d` se interpretan. Usa `-d @body.txt` o comillas simples bien anidadas.
- **Confundir base64 con base64url:** los JWT usan `-` y `_` y sin relleno `=`. Por eso la función del paso 7 reajusta el relleno.
- **Confiar en el payload sin verificar:** decodificar no prueba que el servidor acepte el cambio. Siempre reproduce la petición.
- **Tokens en el repositorio:** no guardes tokens, cookies ni hashes reales en archivos versionados; usa el scratchpad.
- **Hydra en Windows:** no es nativo; usa WSL o Kali.
- **Crackear sin formato:** john con formato incorrecto da cero resultados sin error evidente. Confirma con `--show` y con una contraseña conocida.
- **Clave pública con formato distinto:** en confusión de algoritmos, el carácter final de la PEM cambia la firma. Prueba variantes.
- **Fuentes no verificadas:** los comandos marcados como «no verificado» deben probarse en un entorno propio antes de usarse en el reto.

## Fuentes
- JWT attacks — PortSwigger Web Security Academy — https://portswigger.net/web-security/jwt (alg none, algoritmo, weak key, kid, jku, jwk; **verificada**)
- Lab: JWT authentication bypass via unverified signature — PortSwigger — https://portswigger.net/web-security/jwt/lab-jwt-authentication-bypass-via-unverified-signature (**localizada en búsqueda**)
- Lab: JWT authentication bypass via algorithm confusion — PortSwigger — https://portswigger.net/web-security/jwt/algorithm-confusion/lab-jwt-authentication-bypass-via-algorithm-confusion (**localizada en búsqueda**)
- Lab: JWT authentication bypass via algorithm confusion with no exposed key — PortSwigger — https://portswigger.net/web-security/jwt/algorithm-confusion/lab-jwt-authentication-bypass-via-algorithm-confusion-with-no-exposed-key (**localizada en búsqueda**)
- Lab: JWT authentication bypass via weak signing key — PortSwigger — https://portswigger.net/web-security/jwt/lab-jwt-authentication-bypass-via-weak-signing-key (**localizada en búsqueda**)
- Lab: JWT authentication bypass via jwk header injection — PortSwigger — https://portswigger.net/web-security/jwt/lab-jwt-authentication-bypass-via-jwk-header-injection (**localizada en búsqueda**)
- Lab: JWT authentication bypass via jku header injection — PortSwigger — https://portswigger.net/web-security/jwt/lab-jwt-authentication-bypass-via-jku-header-injection (**localizada en búsqueda**)
- Authentication vulnerabilities — PortSwigger — https://portswigger.net/web-security/authentication (**verificada**)
- OAuth 2.0 authentication vulnerabilities — PortSwigger — https://portswigger.net/web-security/oauth (**verificada**)
- The Fragile Lock: Novel Bypasses For SAML Authentication — PortSwigger Research — https://portswigger.net/research/the-fragile-lock (**localizada en búsqueda; no leída completa**)
- SAML roulette: the hacker always wins — PortSwigger Research — https://portswigger.net/research/saml-roulette-the-hacker-always-wins (**localizada en búsqueda; no leída**)
- Página SAML de Web Security Academy — https://portswigger.net/web-security/saml (**devolvió 404; no usada**)
- Example hashes — hashcat wiki — https://hashcat.net/wiki/doku.php?id=example_hashes (**verificada: modos 0, 500, 1000, 1400, 3200, 5600, 13100, 16500**)
- OPTIONS — John the Ripper jumbo — https://github.com/openwall/john/blob/bleeding-jumbo/doc/OPTIONS (**verificada**)
- EXAMPLES — John the Ripper jumbo — https://github.com/openwall/john/blob/bleeding-jumbo/doc/EXAMPLES (**verificada**)
- Documentación general de John — https://www.openwall.com/john/doc/ (**parcial; no muestra --format**)
- jwt_tool — ticarpi — https://github.com/ticarpi/jwt_tool (**verificada: -X a, -X i, -I, -pc, -pv, -hc, -hv, -t, -V, -pk, instalación**)
- Wiki de jwt_tool — https://github.com/ticarpi/jwt_tool/wiki (**no documenta -C, -d, -S ni -pr en la consulta**)
- hydra — vanhauser-thc — https://github.com/vanhauser-thc/thc-hydra (**verificada: módulos, -L, -P, -l, -p, -C, -t**)
- Sintaxis http-post-form (tutoriales recopilados en búsqueda, no oficial) — https://www.github.com/vanhauser-thc/thc-hydra/issues/851 y https://viceintelpro.gitbook.io/viceintelpro/offensive-security/login-brute-forcing/6.-login-forms.md (**secundaria; verificar con hydra -U**)
- NetExec wiki, password spraying — https://netexec.wiki/smb-protocol/password-spraying (**localizada en búsqueda; ejemplo leído en snippet**)
- Cheat sheet NetExec (scjsec) — https://github.com/scjsec/Netexec-cheat-sheet (**secundaria**)
- Paired lists con `--no-bruteforce` — https://hackviser.com/tactics/tools/netexec (**secundaria**)
- Repositorio NetExec — https://github.com/Pennyw0rth/NetExec (**mencionado en búsqueda; no visitado**)

## Relación con otros planes
- `04-aplicaciones-web.md`: formularios, cookies, cabeceras y el resto de superficie web que aloja el login.
- `05-bases-datos-consultas.md`: SQLi y NoSQLi en el formulario de login (bypass de contraseña), y el `kid` que llega a una consulta.
- `02-red-conexiones.md`: servicios de autenticación remota (SSH, SMB, RDP, LDAP) que se prueban con spraying y hydra.
- `07-osint-reconocimiento.md`: origen de listas de usuarios y de patrones de contraseña (nombre de empresa, año).
- Planes futuros de la biblioteca (`analisis/`): se completarán según se añadan.

## Autorización
Es metodología. Aplícala a un objetivo solo si figura en un `ctf/SCOPE.md` confirmado. Ninguna recomendación de este plan se ejecuta sin esa confirmación. Las acciones de fuerza bruta, spraying, forja de tokens, bypass de 2FA y restablecimiento de contraseñas son propuestas pendientes de aprobación del usuario, y deben respetar los límites de intentos y de bloqueo que fije el reto.
