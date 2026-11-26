param(
    [Parameter(Mandatory)][int]$N,
    [Parameter(Mandatory)][string]$Tarea,
    [Parameter(Mandatory)][string]$PromptFile,
    [switch]$Red,
    [string]$MarkerDir = $env:TEMP
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "Codex $N - $Tarea"
$root = Split-Path -Parent $PSScriptRoot
$exitMarker = Join-Path $MarkerDir "codex$N.exit"
$doneMarker = Join-Path $MarkerDir "codex$N.done"

foreach ($marker in @($exitMarker, $doneMarker)) {
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
}

$exitCode = 1
try {
    $prompt = Get-Item -LiteralPath $PromptFile
    $nmapPath = @('C:\Program Files (x86)\Nmap', 'C:\Program Files\Nmap') |
        Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
        Select-Object -First 1
    if ($nmapPath) { $env:PATH = "$nmapPath;$env:PATH" }

    $codexArgs = @('-s', 'workspace-write', '-a', 'never', '-C', $root, '--add-dir', $prompt.DirectoryName)
    if ($Red) { $codexArgs += @('-c', 'sandbox_workspace_write.network_access=true') }
    $codexArgs += "Lee el archivo $($prompt.FullName) y ejecuta exactamente las instrucciones que contiene."

    & codex @codexArgs
    $exitCode = $global:LASTEXITCODE
} finally {
    Set-Content -LiteralPath $exitMarker -Value "exit=$exitCode $(Get-Date -Format o)" -Encoding ascii
    Write-Host "=== Codex terminó (exit $exitCode). Puedes cerrar esta ventana. ==="
}
