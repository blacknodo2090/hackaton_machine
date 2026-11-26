param(
    [Parameter(Mandatory)][ValidateSet('research', 'tool')][string]$Script,
    [Parameter(Mandatory)][ValidateScript({ $_.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -lt 0 })][string]$Tarea,
    [string]$MarkerDir = $env:TEMP,
    [Parameter(ValueFromRemainingArguments)][string[]]$Args
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "Gemini - $Tarea"
$env:GEMINI_API_KEY = [Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($env:GEMINI_API_KEY)) {
    Write-Warning 'GEMINI_API_KEY no esta configurada en el entorno de usuario de Windows.'
    exit 2
}

$npmPath = Join-Path $env:APPDATA 'npm'
$nmapPath = @('C:\Program Files (x86)\Nmap', 'C:\Program Files\Nmap') |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if ($nmapPath) { $env:PATH = "$nmapPath;$env:PATH" }
$env:PATH = "$npmPath;$env:PATH"

$exitMarker = Join-Path $MarkerDir "gemini.$Tarea.exit"
if (Test-Path -LiteralPath $exitMarker) { Remove-Item -LiteralPath $exitMarker }

$exitCode = 1
try {
    $scriptName = @{ research = 'ask-gemini.ps1'; tool = 'ask-gemini-tool.ps1' }[$Script]
    $geminiScript = Join-Path $PSScriptRoot $scriptName
    $parameters = (Get-Command -Name $geminiScript).Parameters

    # En PowerShell 5.1, un array de strings solo reenvia argumentos posicionales.
    $namedArgs = @{}
    $positionalArgs = @()
    for ($i = 0; $i -lt $Args.Count; $i++) {
        $argument = $Args[$i]
        if ($argument -notmatch '^-([a-zA-Z][a-zA-Z0-9_]*)$') {
            $positionalArgs += $argument
            continue
        }

        $name = $Matches[1]
        if (-not $parameters.ContainsKey($name)) { throw "Parametro desconocido: $argument." }
        if ($namedArgs.ContainsKey($name)) { throw "Parametro repetido: $argument." }
        if ($parameters[$name].SwitchParameter) {
            $namedArgs.Add($name, $true)
            continue
        }

        $i++
        if ($i -ge $Args.Count) { throw "Falta el valor de $argument." }
        $namedArgs.Add($name, $Args[$i])
    }

    $global:LASTEXITCODE = 0
    & $geminiScript @namedArgs @positionalArgs
    $exitCode = $global:LASTEXITCODE
} finally {
    Set-Content -LiteralPath $exitMarker -Value "exit=$exitCode $(Get-Date -Format o)" -Encoding ascii
}
