# Plan de análisis 08 — Ingeniería social

- **Punto de vista:** el factor humano como superficie de ataque en un ejercicio autorizado. Cubre reconocimiento de personas y correos (OSINT orientado a humanos), phishing y spear-phishing de laboratorio, pretexting, páginas de captura de credenciales, documentos con macros o enlaces (maldocs) y el análisis de retos tipo "social" o de correo en CTF. En un CTF importa porque muchos retos esconden la pista en un correo, una cabecera, un adjunto o una página que imita a un servicio, y el siguiente paso suele salir de ahí.
- **Cuándo aplicarlo:** el reto entrega un `.eml`, un mensaje, un documento Office o un PDF con enlaces; menciona personal, correos, remitentes o "ingeniería social"; pide analizar una página de login sospechosa; o el alcance autoriza explícitamente una simulación de phishing dentro de un laboratorio o plataforma CTF. Sin esa autorización explícita, este plan se limita al análisis pasivo de material que ya está en manos del equipo.

Convención: **[V]** = comprobado en la fuente indicada durante la investigación; **[NP]** = no probado en este entorno, tomado de documentación o práctica habitual, a validar antes de depender de ello. Sustituye `<dominio>`, `<correo>` y `<host-lab>` solo con valores del `ctf/SCOPE.md` confirmado.

## Preparación
- **Alcance y encuadre ético:** verifica que el objetivo figure en un `ctf/SCOPE.md` confirmado. Para simulaciones de phishing, el alcance debe nombrar los destinatarios (en CTF, cuentas o buzones del propio reto o del laboratorio), las plataformas permitidas y la ventana temporal. Nunca envíes correos a personas reales que no estén en el alcance, ni uses nombres, fotos o cuentas reales de terceros como señuelo.
- **Infraestructura de laboratorio:** usa un servidor SMTP de prueba o un buzón del reto, y un host de laboratorio (`<host-lab>`) para cualquier página de captura. No registres dominios reales similares a marcas o instituciones reales.
- **Registro de trabajo:** carpeta `ctf/<reto>/social/` con cada correo, cabecera, enlace, hash de adjunto y comando usado, con fecha. Así cada hallazgo es reproducible y auditable.
- **Secretos:** las credenciales capturadas en un laboratorio son datos del reto. Guárdalas en `ctf/<reto>/loot/` (ignorado por git si así está configurado) y no en archivos versionados ni en el historial de comandos.
- **Windows nativo:** PowerShell cubre el análisis de cabeceras y DNS (`Resolve-DnsName`, `Get-Content`). Gophish tiene binarios para Windows [V].
- **Kali/WSL:** recomendado para SET (`apt install set`) y para el flujo completo de captura en laboratorio [V en la página de Kali].

## Herramientas
| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| theHarvester | Correos, nombres, subdominios e IPs desde fuentes pasivas; fuentes de personas y filtraciones con selectores (`-b`) | Ambos con `uv` (`uv sync`, `uv run theHarvester`) [V en README; requiere Python 3.14 según el repo]. Windows: [NP] |
| Maltego (Community/Graph) | Grafo de relaciones entre personas, dominios, correos y organizaciones | [NP: la página oficial no indica sistemas soportados ni diferencias entre ediciones; verifica en la página de descargas] |
| OSINT Framework | Directorio de fuentes por tipo de dato (correo, nombre de usuario, dominio) | Navegador en ambos [V, ver plan 07] |
| Gophish | Campañas de phishing de laboratorio: plantillas, páginas de destino, grupos de destinatarios y métricas | Windows (binario) [V]; Kali-WSL o Docker [V: imagen oficial] |
| Social-Engineer Toolkit (SET) | Vectores de ingeniería social, incluido el *Credential Harvester* de clonación de página, para laboratorio | Kali-WSL: `sudo apt install set`, ejecutar `setoolkit` [V]. Windows nativo: no soportado en esta investigación [NP] |
| exiftool | Metadatos de adjuntos (autor, software, rutas internas) | Windows `exiftool.exe` o `perl exiftool`; Kali-WSL con apt [V, ver plan 07] |
| `Resolve-DnsName` / `dig` | Registros TXT (SPF), `_dmarc` (DMARC), MX | Windows nativo [NP] / Kali-WSL con `dig` [NP] |
| Editor de cabeceras (PowerShell o Python estándar) | Parseo de `.eml`: `From`, `Reply-To`, `Return-Path`, `Received`, `Authentication-Results` | Ambos [NP: práctica habitual] |
| MITRE ATT&CK Navigator | Mapear las técnicas usadas en el ejercicio y el resultado | Navegador en ambos [NP] |

> **Catálogo Kali:** ver [KALI_CATALOG.md](../docs/tools/KALI_CATALOG.md) → Resource Development · Initial Access.

## Procedimiento paso a paso

1. **Confirmar alcance y reglas del ejercicio.** Lee `ctf/SCOPE.md`. Anota qué personas o buzones están dentro, qué vectores están permitidos (correo, web, adjuntos) y qué queda prohibido. Si el reto solo pide analizar un correo, salta a los pasos 6 y 7.

2. **Reconocimiento de personas y correos (OSINT → humano).** Qué hace: identifica el formato de correos corporativos, roles y relaciones dentro de la organización del reto.
   ```bash
   uv run theHarvester -d <dominio> -b crtsh,certspotter
   uv run theHarvester -d <dominio> -b emails,people -f social_<dominio>
   ```
   Usa solo fuentes pasivas y las que requieren clave únicamente si el alcance lo permite [V: el README indica claves en `~/.theHarvester/api-keys.yaml`, que no debe versionarse]. Documenta cada nombre y correo con su fuente. Si el reto da un nombre, búscalo en fuentes públicas sin intentar acceder a cuentas.

3. **Deducir el formato de correo y la cadena de confianza.** Qué hace: a partir de correos encontrados (`nombre.apellido@`, `inicial+apellido@`), infiere el patrón y verifica si el dominio tiene SPF, DKIM y DMARC, que determinan qué suplantaciones son posibles en el laboratorio.
   ```powershell
   Resolve-DnsName -Name <dominio> -Type TXT
   Resolve-DnsName -Name _dmarc.<dominio> -Type TXT
   ```
   Interpreta: SPF `-all` o DMARC `p=reject` indican una defensa que el ejercicio debe nombrar como restricción; ausencia de DMARC indica una superficie más débil [NP: lectura estándar de SPF/DMARC; RFC 7208 y RFC 7489 no consultados en esta sesión].

4. **Diseñar el pretexto en el documento del reto.** Qué hace: define el escenario (remitente, asunto, motivo, urgencia) como hipótesis a probar, no como correo real. Documenta el objetivo del pretexto (p. ej. que el destinatario introduzca una credencial de prueba en una página de laboratorio) y el resultado esperado.

5. **Análisis de maldocs y enlaces en laboratorio.** Qué hace: examina adjuntos y enlaces del reto sin ejecutarlos.
   ```bash
   exiftool -a -G1 -s <adjunto>
   sha256sum <adjunto>
   ```
   Para enlaces, desenmascara acortadores y redirecciones con una petición sin seguirlas automáticamente (`curl -sI <url>`) y registra cada salto [NP: práctica habitual]. Clasifica el adjunto como técnica de MITRE: T1566.001 (adjunto), T1566.002 (enlace) o T1598 (recopilación de información por phishing) [V: definiciones en attack.mitre.org].

6. **Análisis de un `.eml` o mensaje de CTF.** Qué hace: revela el remitente real, la ruta de entrega y la autenticación.
   ```powershell
   Get-Content .\mensaje.eml | Select-String -Pattern '^(From|Reply-To|Return-Path|Received|Authentication-Results|Subject):'
   ```
   Compara `From` con `Return-Path` y `Reply-To`; revisa `Authentication-Results` para SPF, DKIM y DMARC; ordena las cabeceras `Received` de abajo arriba para ver la ruta. Extrae los enlaces y adjuntos del cuerpo para el paso 5.

7. **Captura de credenciales en laboratorio con Gophish (solo entorno autorizado).** Qué hace: simula una campaña con métricas (envío, clic, datos introducidos) sobre `<host-lab>`.
   - Ejecuta el binario de Gophish (Windows) o el contenedor oficial, y abre `https://localhost:3333` [V]. En versiones desde la 0.10.1 la contraseña de `admin` se genera y se imprime en el log de arranque; versiones anteriores usaban `gophish` [V].
   - Configura un perfil de envío apuntando al SMTP de prueba, una plantilla de correo, una página de destino de laboratorio y un grupo con solo los destinatarios del alcance.
   - Lanza la campaña, revisa métricas y exporta resultados. Desactívala al terminar.
   - Puertos del servidor de destino y configuración TLS: [NP: no verificados en esta sesión; consulta la documentación de Gophish].

8. **Captura con SET en Kali-WSL (solo laboratorio).** Qué hace: clona una página de login de prueba y registra las credenciales enviadas, como ejercicio de comprensión del vector.
   ```bash
   sudo apt install set
   sudo setoolkit
   ```
   Al primer arranque acepta los términos, que limitan el uso a fines lícitos autorizados por la organización evaluada [V: página de Kali]. Navega en el menú a los ataques de ingeniería social y al vector de sitio web con *Credential Harvester*; los números exactos de menú cambian entre versiones [NP: verifica en la ayuda de tu versión]. Usa solo `<host-lab>`.

9. **Análisis de la página capturada (reto tipo "login falso").** Qué hace: si el reto entrega una página o un HTML, examina formularios, destino del `action`, scripts y dominio de envío.
   ```bash
   curl -s <url> | grep -iE '<form|action=|<script|http'
   ```
   Lee el HTML sin ejecutar scripts. Anota a dónde envía el formulario y si hay ofuscación. Esto alimenta el plan 04 (aplicaciones web) si la página es parte de la superficie.

10. **Registro final.** Guarda en `ctf/<reto>/social/` el resumen con: personas y correos confirmados, formato inferido, estado SPF/DKIM/DMARC, cabeceras clave, adjuntos con hash, enlaces desenmascarados, métricas de campaña si existen y las fuentes de cada dato.

## Qué buscar (indicadores de vulnerabilidad)
- **Suplantación posible:** `From` distinto de `Return-Path` o `Reply-To`; `Authentication-Results` con SPF, DKIM o DMARC en `fail`/`none`; dominio sin DMARC o con `p=none` [NP: lectura estándar de cabeceras].
- **Formato de correo predecible:** patrón `nombre.apellido@` deducible de correos ya publicados, o lista de personas con rol de soporte o TI en fuentes públicas.
- **Formularios sospechosos:** `action` que apunta a un dominio distinto del que aparece en el enlace, scripts que envían datos fuera de la página, o campos de contraseña fuera de un dominio de confianza.
- **Adjuntos con contenido activo:** macros en documentos Office, plantillas remotas (`attachedTemplate`), enlaces a recursos externos o metadatos con autor o ruta interna.
- **Acortadores y redirecciones:** cadenas de redirección que terminan en un dominio distinto al prometido.
- **Pistas en el contenido:** nombres de personas, cargos o fechas que contradicen el enunciado; una credencial o un token dentro de una cabecera, un comentario HTML o un campo oculto.

## Cómo interpretar y pasar a la siguiente fase
- Un formulario de login o una página de captura encontrada en el reto pasa al plan **04-aplicaciones-web.md** (aún no existe en `analisis/`; pendiente de creación).
- Un dominio, IP o servidor SMTP descubierto pasa a **02-red-conexiones.md**.
- Nombres, correos y roles confirmados alimentan el plan **07-osint-reconocimiento.md** para completar la superficie.
- Un adjunto con macros o metadatos sensibles pasa al análisis forense o de contenido (plan pendiente de creación).
- Credenciales válidas obtenidas en el laboratorio se usan solo contra el servicio que indica el alcance, y se documentan en `loot/`.
- Propuesta pendiente de aprobación: si el equipo quiere que Gophish y SET formen parte del flujo estándar de CTF o solo de simulaciones explícitamente autorizadas.

## Errores comunes y trampas
- **Confundir simulación con ataque real:** enviar un correo a una persona no incluida en el alcance es un incidente, aunque el objetivo sea "educativo". Limita destinatarios por escrito.
- **Dominios de imitación reales:** registrar un dominio parecido a una marca o institución real puede causar daño y problemas legales. Usa dominios de laboratorio o `localhost`.
- **Confiar en la cabecera `From`:** es fácil de falsificar; la verificación depende de `Authentication-Results` y de la ruta `Received`.
- **Ejecutar adjuntos o abrir enlaces en el equipo principal:** usa una máquina virtual o WSL aislada, y desactiva macros por defecto.
- **Versiones y menús desactualizados:** SET y Gophish cambian sus menús y opciones entre versiones; comprueba la ayuda de tu versión antes de seguir un tutorial.
- **Claves y credenciales en el historial:** no escribas contraseñas o claves en líneas de comando que queden en el historial de shell ni en archivos versionados.
- **Fuentes de terceros no verificadas:** los tutoriales de SET de terceros (incluidos los de 2026 que aparecen en búsquedas) no se han verificado en esta sesión; úsalos solo como referencia.

## Fuentes
- MITRE ATT&CK — T1566 Phishing (Initial Access) — https://attack.mitre.org/techniques/T1566/ (consultada en búsqueda; enlaza también T1566.002 Spearphishing Link: https://attack.mitre.org/techniques/T1566/002/)
- MITRE ATT&CK — T1598 Phishing for Information (Reconnaissance), con mitigaciones M1054 y M1017 y detecciones — https://attack.mitre.org/techniques/T1598/ (consultada)
- Kali Linux — Tool: set (Social-Engineer Toolkit) — https://www.kali.org/tools/set/ (consultada: instalación, nombre `setoolkit`, aviso de términos de uso)
- TrustedSec — Social-Engineer Toolkit (repositorio oficial) — https://github.com/trustedsec/social-engineer-toolkit (listada en búsqueda; contenido no leído directamente)
- Gophish — repositorio oficial — https://github.com/gophish/gophish (consultada: instalación, puerto 3333, contraseña de primer inicio)
- Gophish — guía de usuario — https://github.com/gophish/user-guide (listada en búsqueda; no leída)
- laramies — theHarvester — https://github.com/laramies/theHarvester (consultada: uso, `uv`, fuentes y claves API)
- Maltego — https://www.maltego.com/ (consultada parcialmente: producto y ediciones; sistemas soportados no indicados)
- OSINT Framework — https://osintframework.com/ (referenciada en plan 07)
- RFC 7208 (SPF) y RFC 7489 (DMARC) — no consultadas en esta sesión; referencia de práctica estándar [NP]

## Relación con otros planes
- `07-osint-reconocimiento.md`: comparte dominio, theHarvester, exiftool y OSINT Framework. Este plan añade la capa humana (personas, correos, pretexto).
- `02-red-conexiones.md`: servidores SMTP, IPs y puertos que se descubran o se usen en laboratorio.
- `04-aplicaciones-web.md` (pendiente de creación): páginas de login, formularios y su análisis.
- `05-bases-datos-consultas.md`: credenciales capturadas o filtradas que puedan usarse en consultas del reto, solo dentro del alcance.
- Planes de forense y de documentos (pendientes de creación): análisis profundo de adjuntos y cabeceras.

## Autorización
- Este documento es metodología de la biblioteca `analisis/`. No investiga ningún objetivo concreto.
- Ninguna fase activa (envío de correos, despliegue de páginas, captura de credenciales, consultas a dominios reales) se ejecuta sin que el objetivo figure en un `ctf/SCOPE.md` confirmado, con destinatarios y vectores permitidos por escrito.
- En el momento de redactar este plan, `ctf/SCOPE.md` confirmado no existe; solo está la plantilla `ctf/targets/_TEMPLATE/SCOPE.md` [V: listado de archivos].
- Si el objetivo o un destinatario está fuera del alcance, no se investiga ni se contacta.
