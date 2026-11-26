<#
.SYNOPSIS
  Encarga una investigacion a Gemini CLI en modo headless y guarda el informe
  en docs/research/<tema>.md siguiendo docs/research/TEMPLATE.md.

.DESCRIPTION
  Gemini se ejecuta en modo "plan" (solo lectura): puede buscar en internet y
  leer el proyecto, pero no editar archivos ni ejecutar comandos. Este script
  es quien escribe el informe, y nunca sobrescribe uno existente.

.EXAMPLE
  .\scripts\ask-gemini.ps1 -Tema stack-web -Pregunta "Compara Next.js y SvelteKit para una demo de 48 h" -Contexto "Equipo de 3, despliegue gratuito"
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')][string]$Tema,
    [Parameter(Mandatory)][string]$Pregunta,
    [string]$Contexto = '',
    [string]$Alcance = '',
    [string]$SolicitadoPor = 'Claude',
    [int]$TimeoutSec = 900,
    [string]$Modelo = 'gemini-3.5-flash-lite'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$template = Join-Path $root 'docs\research\TEMPLATE.md'
$report = Join-Path $root "docs\research\$Tema.md"

if (Test-Path $report) { throw "Ya existe $report. Usa otro -Tema; no se sobrescriben informes." }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$fecha = Get-Date -Format 'yyyy-MM-dd'
$plantilla = [IO.File]::ReadAllText($template, $utf8)

$prompt = @"
Eres el agente de investigacion del equipo (lee GEMINI.md y gemini/CONTEXT.md).
Investiga en internet la siguiente pregunta usando tus herramientas de busqueda
web y lectura de paginas. Prioriza fuentes primarias y oficiales, verifica fechas
y versiones, y no inventes enlaces: incluye solo URLs que hayas consultado.

Pregunta: $Pregunta
Contexto del proyecto: $Contexto
Alcance: $Alcance
Fecha de hoy: $fecha
Solicitado por: $SolicitadoPor

Formato de salida OBLIGATORIO: responde UNICAMENTE con el informe completo en
Markdown, en espanol, siguiendo exactamente esta plantilla (rellena todos los
campos; separa hechos, analisis y recomendacion; la recomendacion no es una
decision aprobada). No escribas archivos: tu respuesta se guardara como informe.
Sin texto antes ni despues del informe y sin bloque de codigo envolvente.

--- PLANTILLA ---
$plantilla
"@

$tmp = Join-Path $env:TEMP "ask-gemini-$Tema-$(Get-Random)"
New-Item -ItemType Directory -Force $tmp | Out-Null
$inFile = Join-Path $tmp 'prompt.txt'
$outFile = Join-Path $tmp 'stdout.txt'
$errFile = Join-Path $tmp 'stderr.txt'
[IO.File]::WriteAllText($inFile, $prompt, $utf8)

$geminiArgs = '/c gemini -p "Sigue las instrucciones recibidas por stdin." --approval-mode plan --skip-trust -o text'
if ($Modelo) { $geminiArgs += " -m $Modelo" }

Write-Host "Gemini investigando '$Tema' (timeout $TimeoutSec s)..."
$p = Start-Process -FilePath cmd.exe -ArgumentList $geminiArgs -WorkingDirectory $root `
    -RedirectStandardInput $inFile -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
    -NoNewWindow -PassThru
$null = $p.Handle  # necesario para que ExitCode quede disponible

if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    & taskkill /PID $p.Id /T /F | Out-Null
    throw "Timeout tras $TimeoutSec s. Log: $errFile"
}

$out = [IO.File]::ReadAllText($outFile, $utf8).Trim()
$err = [IO.File]::ReadAllText($errFile, $utf8)

if ($err -match '429|RESOURCE_EXHAUSTED') { Write-Warning "Gemini reporto cuota agotada (429). Revisa $errFile" }
if ($p.ExitCode -ne 0 -or -not $out) { throw "Gemini fallo (exit $($p.ExitCode)). Log: $errFile" }

# Quitar un bloque ```markdown envolvente si lo hubiera.
$out = $out -replace '^\s*```(markdown|md)?\s*\r?\n', '' -replace '\r?\n```\s*$', ''
if ($out -notmatch '^\s*# Informe de investigaci') {
    Write-Warning "La salida no empieza con el encabezado de la plantilla; revisala antes de integrarla."
}

[IO.File]::WriteAllText($report, $out + "`n", $utf8)
Write-Host "Informe guardado en $report"
