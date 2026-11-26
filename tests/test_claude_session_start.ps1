$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$hook = Join-Path $root 'scripts/claude-session-start.ps1'
$launcher = Join-Path $root 'scripts/start-agents.ps1'
$simulacion = [pscustomobject]@{ Procesos = @(); FalloCim = $false; Consultas = 0; Aperturas = @() }

function Get-CimInstance($ClassName, $Filter, $OperationTimeoutSec) {
    $simulacion.Consultas++
    if ($ClassName -ne 'Win32_Process') { throw 'Clase CIM incorrecta.' }
    if ($simulacion.FalloCim) { throw 'CIM de prueba no disponible.' }
    $simulacion.Procesos
}

function Start-Process($FilePath, $ArgumentList, $WorkingDirectory, $WindowStyle) {
    $simulacion.Aperturas += [pscustomobject]@{
        Programa = $FilePath
        Argumentos = $ArgumentList
        Carpeta = $WorkingDirectory
        Visibilidad = $WindowStyle
    }
}

function Invoke-HookTest([string]$Evento) {
    $simulacion.Consultas = 0
    $simulacion.Aperturas = @()
    $entrada = [IO.StringReader]::new($Evento)
    try {
        [Console]::SetIn($entrada)
        $salida = & $hook
        if ($LASTEXITCODE -ne 0) { throw "Salida inesperada del hook: $LASTEXITCODE" }
        $salida[-1].Trim()
    } finally {
        $entrada.Dispose()
    }
}

function Assert-Estado([string]$Obtenido, [string]$Esperado) {
    if ($Obtenido -cne "Estado de agentes | $Esperado") { throw "Estado inesperado: $Obtenido" }
}

function Assert-Apertura([string]$Agentes) {
    $apertura = $simulacion.Aperturas[0]
    $comando = '"& ' + "'" + $launcher.Replace("'", "''") + "' -Agentes $Agentes" + '"'
    if ($simulacion.Aperturas.Count -ne 1 -or $apertura.Programa -ne 'powershell.exe' -or
        $apertura.Argumentos[-2] -ne '-Command' -or $apertura.Argumentos[-1] -cne $comando -or
        $apertura.Carpeta -ne $root -or $apertura.Visibilidad -ne 'Hidden') {
        throw "Se esperaba una llamada asincrona para $Agentes."
    }
}

$entradaOriginal = [Console]::In
$encodingOriginal = [Console]::OutputEncoding
$optOutOriginal = $env:HACKATON_NO_AUTOSTART
$flagOriginal = $env:HACKATON_AGENTS_LAUNCHED
$inicio = '{"source":"startup"}'

try {
    $env:HACKATON_NO_AUTOSTART = '1'
    $env:HACKATON_AGENTS_LAUNCHED = $null
    Assert-Estado (Invoke-HookTest $inicio) 'omitidos: gemini, codex (HACKATON_NO_AUTOSTART=1)'
    if ($simulacion.Aperturas.Count -or $simulacion.Consultas) { throw 'El opt-out debe evitar consultas y aperturas.' }

    $env:HACKATON_NO_AUTOSTART = $null
    $env:HACKATON_AGENTS_LAUNCHED = '1'
    Assert-Estado (Invoke-HookTest $inicio) 'omitidos: gemini, codex (HACKATON_AGENTS_LAUNCHED=1)'
    if ($simulacion.Aperturas.Count -or $simulacion.Consultas) { throw 'La marca heredada debe evitar consultas y aperturas.' }

    $env:HACKATON_AGENTS_LAUNCHED = $null
    foreach ($evento in @('resume', 'clear', 'compact')) {
        Assert-Estado (Invoke-HookTest ('{"source":"' + $evento + '"}')) "omitidos: gemini, codex (evento distinto de startup ($evento))"
        if ($simulacion.Aperturas.Count -or $simulacion.Consultas) { throw "El evento $evento debe evitar consultas y aperturas." }
    }

    $simulacion.Procesos = @([pscustomobject]@{ CommandLine = 'powershell.exe -File "C:\otro\scripts\start-agents.ps1" -Agente codex' })
    Assert-Estado (Invoke-HookTest $inicio) 'apertura solicitada: gemini, codex'
    Assert-Apertura 'gemini,codex'

    $simulacion.Procesos += [pscustomobject]@{ CommandLine = "powershell.exe -File `"$launcher`" -Agente gemini" }
    Assert-Estado (Invoke-HookTest $inicio) 'apertura solicitada: codex | activos o en apertura: gemini'
    Assert-Apertura 'codex'

    $simulacion.Procesos += [pscustomobject]@{ CommandLine = "powershell.exe -Command `"& '$launcher' -Agentes codex`"" }
    Assert-Estado (Invoke-HookTest $inicio) 'activos o en apertura: gemini, codex'
    if ($simulacion.Aperturas.Count) { throw 'Se intento duplicar agentes.' }

    $simulacion.FalloCim = $true
    Assert-Estado (Invoke-HookTest $inicio) 'omitidos: gemini, codex (error del hook (CIM de prueba no disponible.))'
    if ($simulacion.Aperturas.Count) { throw 'Se intento abrir agentes tras un fallo de CIM.' }

    Write-Host 'Pruebas simuladas del hook OK.'
} finally {
    [Console]::SetIn($entradaOriginal)
    [Console]::OutputEncoding = $encodingOriginal
    $env:HACKATON_NO_AUTOSTART = $optOutOriginal
    $env:HACKATON_AGENTS_LAUNCHED = $flagOriginal
}
