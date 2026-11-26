<#
.SYNOPSIS
  Inicia Claude (orquestador), Gemini (investigacion) y Codex (implementacion)
  en la raiz del proyecto, cada uno con su contexto y su rol.

.DESCRIPTION
  Sin -Agente, abre Windows Terminal con un panel por agente (o pestanas, o
  ventanas de PowerShell si no hay Windows Terminal). Cada panel vuelve a
  llamar a este script con -Agente <nombre>, que lanza la CLI correspondiente
  en modo interactivo con un prompt inicial: leer sus instrucciones
  (CLAUDE.md / GEMINI.md / AGENTS.md), docs/COMMON_CONTEXT.md, sus notas en
  <agente>/CONTEXT.md, el brief y las decisiones; confirmar su rol y esperar.

  Los agentes no se hablan entre si: se coordinan mediante los archivos del
  workspace (docs/research/, docs/DECISIONS.md, docs/COMMON_CONTEXT.md).

.EXAMPLE
  .\scripts\start-agents.ps1
  Los 3 agentes en paneles: Claude a la izquierda, Gemini y Codex a la derecha.

.EXAMPLE
  .\scripts\start-agents.ps1 -Agentes claude,codex -Modo pestanas

.EXAMPLE
  .\scripts\start-agents.ps1 -Agente gemini
  Arranca solo Gemini en la terminal actual.
#>
param(
    [ValidateSet('claude', 'gemini', 'codex')][string[]]$Agentes = @('claude', 'gemini', 'codex'),
    [ValidateSet('paneles', 'pestanas', 'ventanas')][string]$Modo = 'paneles',
    [ValidateSet('claude', 'gemini', 'codex')][string]$Agente = '',
    [switch]$SinPrompt
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$self = $PSCommandPath

$comun = 'docs/COMMON_CONTEXT.md, docs/AI_WORKFLOW.md, docs/PRODUCT_BRIEF.md y docs/DECISIONS.md'
$cierre = 'Responde en espanol con un resumen breve: tu rol, el estado actual del proyecto, tareas o pendientes que veas y lo que necesitas del usuario. No modifiques archivos todavia; espera instrucciones.'

$perfiles = @{
    claude = @{
        Titulo = 'Claude - Orquestador'
        Cli    = 'claude'
        Prompt = "Inicio de sesion del equipo. Lee CLAUDE.md, AGENTS.md, claude/CONTEXT.md, $comun. Tu rol: ORQUESTADOR. Conviertes las prioridades del usuario (supervisor, ultima palabra) en tareas; delegas la investigacion a Gemini con scripts/ask-gemini.ps1 y la implementacion y comandos a Codex; integras resultados y mantienes docs/DECISIONS.md solo con decisiones aprobadas. Gemini y Codex estan abiertos en otros paneles. $cierre"
    }
    gemini = @{
        Titulo = 'Gemini - Investigacion'
        Cli    = 'gemini'
        Prompt = "Inicio de sesion del equipo. Lee GEMINI.md, AGENTS.md, gemini/CONTEXT.md, $comun y docs/research/TEMPLATE.md. Tu rol: INVESTIGACION. Buscas en internet lo que pidan Claude o el usuario, con fuentes fiables y enlaces, separando hechos, analisis y recomendacion. Entregas cada informe nuevo en docs/research/<tema>.md. No implementas codigo ni editas docs/DECISIONS.md. $cierre"
    }
    codex  = @{
        Titulo = 'Codex - Implementacion'
        Cli    = 'codex'
        Prompt = "Inicio de sesion del equipo. Lee AGENTS.md, codex/CONTEXT.md y $comun. Tu rol: IMPLEMENTACION Y COMANDOS. Implementas lo que asignen Claude o el usuario, ejecutas pruebas y comprobaciones y reportas cambios, comandos y resultados. No cambias alcance ni decisiones por tu cuenta y no sobrescribes trabajo ajeno. $cierre"
    }
}

# --- Modo agente: lanza una CLI en esta terminal ------------------------------
if ($Agente) {
    $p = $perfiles[$Agente]
    Set-Location $root
    $Host.UI.RawUI.WindowTitle = $p.Titulo
    if (-not (Get-Command $p.Cli -ErrorAction SilentlyContinue)) {
        throw "No se encontro '$($p.Cli)' en el PATH. Instalalo y autenticate segun docs/AI_WORKFLOW.md."
    }
    Write-Host "== $($p.Titulo) ==  ($root)" -ForegroundColor Cyan
    $cliArgs = @()
    if ($Agente -eq 'gemini') { $cliArgs += @('-m', 'gemini-3.5-flash-lite') }
    if (-not $SinPrompt) {
        # gemini necesita -i para ejecutar el prompt y seguir en modo interactivo;
        # claude y codex aceptan el prompt como argumento posicional.
        if ($Agente -eq 'gemini') { $cliArgs += '-i' }
        $cliArgs += $p.Prompt
    }
    $env:HACKATON_AGENTS_LAUNCHED = '1'
    & $p.Cli @cliArgs
    return
}

# --- Modo lanzador: abre una terminal por agente ------------------------------
$faltan = $Agentes | Where-Object { -not (Get-Command $perfiles[$_].Cli -ErrorAction SilentlyContinue) }
if ($faltan) { Write-Warning "No estan en el PATH: $($faltan -join ', '). Sus paneles mostraran el error." }

function Get-AgentCommand([string]$nombre) {
    $c = @('powershell.exe', '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self, '-Agente', $nombre)
    if ($SinPrompt) { $c += '-SinPrompt' }
    return $c
}

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue
if ($Modo -eq 'ventanas' -or -not $wt) {
    if (-not $wt -and $Modo -ne 'ventanas') { Write-Warning 'Windows Terminal no encontrado; se abren ventanas de PowerShell.' }
    foreach ($a in $Agentes) {
        $c = Get-AgentCommand $a
        Start-Process -FilePath $c[0] -ArgumentList ($c[1..($c.Count - 1)] | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -WorkingDirectory $root
    }
    Write-Host "Abiertas $($Agentes.Count) ventanas: $($Agentes -join ', ')."
    return
}

# Windows Terminal: primer agente en pestana nueva; el resto en paneles o pestanas.
$wtArgs = @('-w', 'new')
for ($i = 0; $i -lt $Agentes.Count; $i++) {
    $a = $Agentes[$i]
    if ($i -gt 0) { $wtArgs += ';' }
    if ($i -eq 0 -or $Modo -eq 'pestanas') {
        $wtArgs += 'new-tab'
    } elseif ($i -eq 1) {
        $wtArgs += @('split-pane', '-V', '-s', '0.5')   # derecha
    } else {
        $wtArgs += @('split-pane', '-H')                 # debajo del panel derecho
    }
    $wtArgs += @('-d', $root, '--title', $perfiles[$a].Titulo, '--suppressApplicationTitle')
    $wtArgs += Get-AgentCommand $a
}

& $wt.Source @wtArgs
Write-Host "Windows Terminal abierto con: $($Agentes -join ', ') ($Modo)."
