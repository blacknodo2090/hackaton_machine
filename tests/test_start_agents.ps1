$ErrorActionPreference = 'Stop'
$launcher = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/start-agents.ps1'
$captura = [pscustomobject]@{ Argumentos = @() }

function gemini {
    $captura.Argumentos = @($args)
}

$tituloOriginal = $Host.UI.RawUI.WindowTitle
$marcaOriginal = $env:HACKATON_AGENTS_LAUNCHED
Push-Location
try {
    & $launcher -Agente gemini
    $argumentos = $captura.Argumentos
    if ($argumentos.Count -ne 4 -or ($argumentos[0..2] -join ' ') -cne '-m gemini-3.5-flash-lite -i' -or
        $argumentos[3] -notmatch '^Inicio de sesion') {
        throw 'Gemini debe recibir el modelo antes de -i y del prompt.'
    }

    & $launcher -Agente gemini -SinPrompt
    if (($captura.Argumentos -join ' ') -cne '-m gemini-3.5-flash-lite') {
        throw 'Gemini debe recibir el modelo con -SinPrompt.'
    }

    Write-Host 'Pruebas simuladas del lanzador OK.'
} finally {
    Pop-Location
    $env:HACKATON_AGENTS_LAUNCHED = $marcaOriginal
    $Host.UI.RawUI.WindowTitle = $tituloOriginal
}
