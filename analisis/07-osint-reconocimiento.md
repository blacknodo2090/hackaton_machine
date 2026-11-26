# Plan de análisis 07 — OSINT y reconocimiento pasivo

- **Punto de vista:** recopilar información sobre el objetivo sin enviarle tráfico dirigido: registros de dominio (whois/RDAP), DNS, transparencia de certificados, subdominios en fuentes de terceros, metadatos de documentos públicos, búsquedas avanzadas (dorks) y filtraciones públicas. En un CTF importa porque muchos retos dan una pista inicial (dominio, nombre, correo, imagen o documento) y la bandera o el siguiente paso suelen estar en datos publicados por error.
- **Cuándo aplicarlo:** el reto da un dominio, una organización, nombres de personas, correos, una imagen o un PDF/Office como punto de partida; se menciona "encuentra lo que está expuesto"; o hay que mapear superficie antes de cualquier prueba activa.

Convención: **[V]** = comprobado en la fuente indicada durante la investigación; **[NP]** = no probado en este entorno, tomado de documentación o práctica habitual, a validar antes de depender de ello. Sustituye `<dominio>` y `<archivo>` por los valores del reto solo después de confirmar el alcance.

## Preparación
- **Alcance:** verifica que el objetivo figure en un `ctf/SCOPE.md` confirmado. Sin ese archivo no se investiga el objetivo; este plan es solo metodología.
- **Registro de trabajo:** crea una carpeta por reto (p. ej. `ctf/<reto>/osint/`) y guarda ahí cada salida con fecha y comando usado, para poder reproducir cada hallazgo.
- **Windows nativo:** PowerShell; `nslookup` y el cmdlet `Resolve-DnsName` están disponibles de serie. Herramientas como amass, subfinder o theHarvester se pueden compilar con Go o Python [NP en este entorno].
- **Kali/WSL:** es el entorno recomendado para el conjunto completo (whois, dig, herramientas en apt/Go/Python, exiftool). Instala desde WSL con `sudo apt update` y las herramientas de Kali que necesites [NP: verifica el nombre del paquete con `apt search`].
- **Requisitos de Go:** subfinder indica que requiere go1.26.10 para instalarse [V, README del proyecto]. Comprueba `go version` antes de instalar.
- **Claves de API:** varias fuentes de subfinder y theHarvester requieren claves. Guárdalas fuera del repositorio (variables de entorno o el archivo de configuración de la herramienta), nunca en archivos versionados.

## Herramientas
| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| `nslookup` / `Resolve-DnsName` | Consultas DNS (A, MX, NS, TXT) | Windows nativo [NP] / Kali-WSL con `dig` |
| `dig` (dnsutils/bind9-dnsutils) | Consultas DNS detalladas, transferencias de zona si están permitidas | Kali-WSL [NP] |
| `whois` / RDAP | Propietario, fechas, servidores de nombres del dominio | Kali-WSL `whois` [NP]; RDAP por HTTP en cualquier sistema [NP] |
| crt.sh (web/JSON) | Certificados emitidos y nombres de subdominio | Ambos (navegador o `curl`/`Invoke-RestMethod`) [V en búsqueda; consulta directa no completada] |
| subfinder | Enumeración pasiva de subdominios | Ambos, con Go [V instalación y flags en README] |
| amass (v5) | Enumeración pasiva/activa y mapeo de activos | Ambos, con Go o Homebrew; Docker en cualquier sistema [V en docs oficiales] |
| theHarvester | Subdominios, correos, IPs, URLs y personas desde fuentes pasivas | Ambos, con `uv` o Docker [V en README] |
| exiftool | Metadatos de imágenes, PDF y Office | Windows: `exiftool.exe` o `perl exiftool`; Kali-WSL con apt [V en README: `perl exiftool` y ejecución en Linux] |
| Google / Bing (dorks) y GHDB | Búsqueda de documentos y paneles expuestos | Navegador en ambos [V operadores de Google; GHDB en Exploit-DB] |
| Wayback Machine | Versiones antiguas de páginas, rutas y archivos eliminados | Navegador o API [NP] |
| OSINT Framework | Directorio para elegir recursos por tipo de dato | Navegador [V: sitio y leyenda T/D/R/M] |

> **Catálogo Kali:** ver [KALI_CATALOG.md](../docs/tools/KALI_CATALOG.md) → Reconnaissance.

## Procedimiento paso a paso

1. **Registro del dominio (whois / RDAP).** Qué hace: obtiene titular, fechas de alta y caducidad, y servidores de nombres.
   ```bash
   whois <dominio>
   ```
   En Windows, usa RDAP por HTTP [NP]:
   ```powershell
   Invoke-RestMethod "https://rdap.org/domain/<dominio>" | ConvertTo-Json -Depth 5
   ```
   Anota nombres de contacto, correos y servidores de nombres. Los datos de contacto pueden estar redactados (RGPD); no es un error del análisis.

2. **Registros DNS.** Qué hace: revela IPs, correo, verificaciones de servicios y pistas en registros TXT.
   ```bash
   dig any <dominio> +noall +answer
   dig mx <dominio> +short
   dig ns <dominio> +short
   dig txt <dominio> +short
   ```
   En Windows [NP]:
   ```powershell
   Resolve-DnsName -Name <dominio> -Type A
   Resolve-DnsName -Name <dominio> -Type TXT
   ```
   Nota: `dig any` ya no devuelve todos los registros en muchos servidores; consulta por tipo.

3. **Certificados de transparencia (crt.sh).** Qué hace: lista nombres de certificados emitidos, incluidos subdominios que ya no resuelven. Patrón usado en guías de terceros [V en búsqueda; comprobar con una consulta real antes de automatizar]:
   ```bash
   curl -s "https://crt.sh/?q=%25.<dominio>&output=json" | jq -r '.[].name_value' | sort -u > crtsh_<dominio>.txt
   ```
   Equivalente en PowerShell [NP]:
   ```powershell
   Invoke-RestMethod "https://crt.sh/?q=%25.<dominio>&output=json" | ForEach-Object { $_.name_value } | Sort-Object -Unique
   ```
   Limitación: no hay documentación oficial del formato JSON; respeta sus términos de uso y evita consultas masivas.

4. **Subdominios pasivos con subfinder.** Qué hace: consulta fuentes de terceros sin tocar el objetivo.
   ```bash
   go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
   subfinder -d <dominio> -silent -o subs_subfinder.txt
   subfinder -d <dominio> -all -silent -o subs_all.txt
   ```
   `-all` usa todas las fuentes: más cobertura y más lento. Las fuentes con API requieren clave [V README].

5. **Subdominios pasivos con amass.** Qué hace: enumeración con grafo de activos. Las docs oficiales muestran `enum` con `-d`; `-active` es opcional y activo, no lo uses sin permiso.
   ```bash
   CGO_ENABLED=0 go install -v github.com/owasp-amass/amass/v5/cmd/amass@main
   amass enum -d <dominio> -o amass_<dominio>.txt
   ```
   Docker [V docs oficiales]:
   ```bash
   docker run --rm -it -v ~/.config/amass:/.config/amass amass:latest enum -d <dominio>
   ```
   Nota: la forma `amass enum -passive` que circula en guías antiguas no aparece en la documentación v5 consultada; comprueba `amass enum -h` en tu versión [NP].

6. **Fusionar y depurar subdominios.**
   ```bash
   cat crtsh_<dominio>.txt subs_all.txt amass_<dominio>.txt | sort -u > subdominios.txt
   ```
   Luego resuelve cuáles siguen activos con un resolvedor DNS pasivo (por ejemplo `dig +short A` por nombre) [NP]. Resolver nombres es una consulta DNS normal, no un escaneo; mantenla en la fase de verificación y no la mezcles con fuerza bruta.

7. **Correos, IPs y URLs con theHarvester.** Qué hace: consulta fuentes pasivas y guarda resultados en JSONL.
   ```bash
   git clone https://github.com/laramies/theHarvester.git
   cd theHarvester
   uv sync
   uv run theHarvester -d <dominio> -b crtsh,certspotter -f harvest_crtsh
   uv run theHarvester -d <dominio> -b all -l 100 -f harvest_all
   ```
   `-b` acepta fuentes o selectores (`subdomains`, `emails`, `ips`, `asns`, `urls`, `people`, `breaches`) [V README]. Las fuentes P1/P2 requieren selección explícita.

8. **Dorks en buscadores.** Operadores de Google verificados en la documentación de ayuda [V]: comillas para frase exacta, `site:` para limitar dominio, `filetype:` para tipo de archivo, `-` para excluir, `before:` y `after:` para fechas. Ejemplos (sustituye `<dominio>`):
   ```text
   site:<dominio> filetype:pdf
   site:<dominio> filetype:xlsx OR filetype:csv
   site:<dominio> "index of" 
   site:<dominio> -www
   site:<dominio> "password" filetype:txt
   ```
   Para dorks avanzados (intitle, inurl, paneles de login, errores) consulta la Google Hacking Database [V: catálogo de categorías en exploit-db.com]: https://www.exploit-db.com/google-hacking-database . Lee cada dork antes de ejecutarlo.

9. **Histórico de contenido.** Qué hace: recupera páginas, rutas y archivos que ya no están publicados.
   ```text
   https://web.archive.org/web/*/<dominio>/*
   ```
   Busca rutas de admin, backups (`.bak`, `.zip`, `.sql`) y documentos antiguos [NP: procedimiento habitual; no ejecutado en esta sesión].

10. **Metadatos de documentos e imágenes.** Qué hace: revela autor, software, rutas internas, GPS o fechas.
    ```bash
    exiftool <archivo>
    exiftool -a -G1 -s <archivo>
    exiftool -csv -r ./descargas > metadatos.csv
    ```
    Windows [V README: "perl exiftool" como alternativa]:
    ```powershell
    exiftool.exe <archivo>
    perl exiftool <archivo>
    ```

11. **Documentación pública del personal y la organización.** Usa OSINT Framework para elegir fuentes por tipo de dato (dominio, IP, correo, usuario, documentos) [V sitio; el contenido de categorías no se pudo leer en esta sesión]: https://osintframework.com/ . Revisa redes sociales, repositorios de código y perfiles públicos del objetivo. Si el reto da un nombre de usuario, búscalo en fuentes públicas sin intentar acceder a cuentas.

12. **Filtraciones públicas.** Comprueba si correos del dominio aparecen en bases de filtraciones conocidas (theHarvester usa fuentes como haveibeenpwned con `-b breaches` [V fuentes listadas en README]). No intentes usar credenciales encontradas fuera del alcance del reto.

13. **Registro final.** Guarda en `ctf/<reto>/osint/` un resumen con: dominio, IPs, subdominios confirmados, correos, metadatos relevantes, y las fuentes de cada dato.

## Qué buscar (indicadores de vulnerabilidad)
- **Superficie expuesta:** subdominios de desarrollo, staging, admin, API, `test`, `old`, `backup`; IPs fuera de rango esperado; puertos o servicios mencionados en TXT o SPF.
- **Credenciales y filtraciones:** correos corporativos en filtraciones, contraseñas en repositorios públicos, `.env`, claves de API o tokens en commits o en `index of`.
- **Versiones:** cabeceras de servidor, generador en metadatos (`Producer`, `Creator`, `Software` en exiftool), nombres de versión en URLs y en páginas antiguas (Wayback).
- **Subdominios olvidados:** certificados de nombres que ya no resuelven, o nombres que sí resuelven pero no aparecen enlazados desde la web principal.
- **Fugas en metadatos:** autor, ruta de equipo, coordenadas GPS, fechas de edición que contradicen el enunciado.
- **Datos de contacto:** correos en whois o en registros TXT que sirven para deducir formato de usuario (`nombre.apellido@`).

## Cómo interpretar y pasar a la fase activa
- Un subdominio resuelto con servicio web es la entrada natural al plan **04-aplicaciones-web.md**.
- Puertos o IPs asociadas a servicios de red alimentan el plan **02-red-conexiones.md**.
- Versiones de software detectadas en cabeceras, metadatos o páginas se cruzan con CVE y exploits públicos en los planes de vulnerabilidades correspondientes.
- Un documento con metadatos sensibles o un archivo de respaldo encontrado por dork o Wayback pasa al análisis forense o de contenido (plan de forense si existe).
- Antes de cualquier prueba activa (escaneo, fuerza bruta, login), confirma que el host figura en `ctf/SCOPE.md` y que la fase activa está autorizada en el enunciado.
- Propuesta pendiente de aprobación: el orden de pasos y si se incluye la resolución de subdominios como paso separado de la fase pasiva.

## Errores comunes y trampas
- **Confundir pasivo con inofensivo:** resolver nombres, consultar `-active` de amass o seguir enlaces del objetivo sí genera tráfico hacia él. Mantén la fase pasiva separada.
- **Confiar en un único origen:** crt.sh, subfinder y amass cubren fuentes distintas; fusiona y verifica.
- **Subdominios que ya no existen:** un certificado antiguo no implica un host activo.
- **Datos de whois redactados:** la ausencia de contacto no significa que no haya propietario identificable por otros medios.
- **Dorks que tocan datos reales de terceros:** no uses dorks para acceder a datos personales que no pertenecen al reto.
- **Comandos desactualizados:** la sintaxis de amass v5 y de algunas herramientas ha cambiado; comprueba `-h` en tu versión.
- **Claves de API en el historial:** no escribas claves en comandos que queden en el historial de shell ni en archivos versionados.
- **Rutas de Windows:** `dig` y `whois` no vienen de serie; usa Kali-WSL o las alternativas indicadas.

## Fuentes
- Google Hacking Database — OffSec / Exploit-DB — https://www.exploit-db.com/google-hacking-database (consultada)
- Operadores de búsqueda de Google — Google Search Help — https://support.google.com/websearch/answer/2466433?hl=es (consultada)
- theHarvester — laramies — https://github.com/laramies/theHarvester (consultada)
- subfinder — ProjectDiscovery — https://github.com/projectdiscovery/subfinder (consultada)
- amass — OWASP Amass — https://github.com/owasp-amass/amass (consultada)
- Documentación de amass — OWASP Amass — https://owasp-amass.github.io/docs/ (consultada)
- ExifTool — Phil Harvey — https://github.com/exiftool/exiftool (consultada)
- OSINT Framework — https://osintframework.com/ (consultada; contenido de categorías no legible)
- crt.sh — Sectigo (búsqueda de guías de terceros; consulta directa agotó el tiempo) — https://crt.sh/
- HackTricks, metodología de pentesting — https://book.hacktricks.wiki/en/generic-methodologies-and-resources/pentesting-methodology.html (la redirección a tollbit devolvió 402; contenido no leído)
- Wayback Machine — Internet Archive — https://web.archive.org/ (referencia; no consultada)

## Relación con otros planes
- `02-red-conexiones.md`: IPs, rangos y servicios descubiertos.
- `04-aplicaciones-web.md`: subdominios y URLs con aplicación web.
- Otros planes de análisis en `analisis/` (vulnerabilidades, forense, criptografía, esteganografía) según el tipo de reto. Nota: si alguno no existe aún, es pendiente de creación.

## Autorización
- Este documento es metodología de la biblioteca `analisis/`. No investiga ningún objetivo concreto.
- Aplica estos pasos a un objetivo solo si figura en un `ctf/SCOPE.md` confirmado. Si el objetivo está fuera del alcance, no se investiga.
