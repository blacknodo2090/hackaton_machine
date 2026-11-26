$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testDir = Join-Path ([IO.Path]::GetTempPath()) "hackaton-launchers-$([guid]::NewGuid())"
$originalTitle = $Host.UI.RawUI.WindowTitle
$originalPath = $env:PATH
$originalKey = $env:GEMINI_API_KEY
$capture = @{}

function Assert-Equal($Expected, $Actual) {
    if ($Expected -cne $Actual) { throw "Se esperaba <$Expected>, se obtuvo <$Actual>." }
}

function Assert-Marker($Path, $Code) {
    $marker = Get-Content -LiteralPath $Path
    if ($marker -notmatch "^exit=$Code (.+)$") { throw "Marcador inesperado: $marker" }
    $null = [DateTimeOffset]::ParseExact($Matches[1], 'o', [cultureinfo]::InvariantCulture)
}

function codex {
    $capture.CodexArgs = @($args)
    $capture.CodexTitle = $Host.UI.RawUI.WindowTitle
    $capture.OldMarker = Test-Path -LiteralPath $codexExit
    $global:LASTEXITCODE = 7
}

New-Item -ItemType Directory -Path $testDir | Out-Null
try {
    $prompt = Join-Path $testDir 'prompt con espacios.md'
    $codexExit = Join-Path $testDir 'codex4.exit'
    $codexDone = Join-Path $testDir 'codex4.done'
    Set-Content -LiteralPath $prompt -Value 'Prompt de prueba.'
    Set-Content -LiteralPath $codexExit -Value 'anterior'
    Set-Content -LiteralPath $codexDone -Value 'anterior'
    $codexLauncher = Join-Path $repoRoot 'scripts/run-codex.ps1'
    & $codexLauncher -N 4 -Tarea prueba -PromptFile $prompt -MarkerDir $testDir -Red
    $expected = @('-s', 'workspace-write', '-a', 'never', '-C', $repoRoot, '--add-dir', $testDir,
        '-c', 'sandbox_workspace_write.network_access=true',
        "Lee el archivo $prompt y ejecuta exactamente las instrucciones que contiene.")
    Assert-Equal ($expected -join '|') ($capture.CodexArgs -join '|')
    Assert-Equal 'Codex 4 - prueba' $capture.CodexTitle
    Assert-Equal $false $capture.OldMarker
    Assert-Equal $false (Test-Path -LiteralPath $codexDone)
    Assert-Marker $codexExit 7
    & $codexLauncher -N 4 -Tarea prueba -PromptFile $prompt -MarkerDir $testDir
    Assert-Equal $false ($capture.CodexArgs -ccontains '-c')

    $geminiSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'scripts/run-gemini.ps1')
    $geminiLauncher = Join-Path $testDir 'run-gemini.ps1'
    $keyLookup = "[Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'User')"
    if (-not $geminiSource.Contains($keyLookup)) { throw 'No se encontro la lectura de la clave de usuario.' }
    $geminiExit = Join-Path $testDir 'gemini.prueba.exit'
    Set-Content -LiteralPath $geminiExit -Value 'anterior'
    Set-Content -LiteralPath $geminiLauncher -Value ($geminiSource.Replace($keyLookup, '$null'))
    & $geminiLauncher -Script tool -Tarea prueba -MarkerDir $testDir
    Assert-Equal 2 $LASTEXITCODE
    Assert-Equal 'anterior' (Get-Content -LiteralPath $geminiExit)

    Set-Content -LiteralPath $geminiLauncher -Value ($geminiSource.Replace($keyLookup, "'valor-simulado'"))
    Set-Content -LiteralPath (Join-Path $testDir 'ask-gemini-tool.ps1') -Value @'
param([string]$Programa, [string]$Enfoque, [switch]$Actualizar)
$capture.Tool = @($Programa, $Enfoque, [bool]$Actualizar) -join '|'
$capture.KeyLoaded = $env:GEMINI_API_KEY -eq 'valor-simulado'
$capture.PathFirst = ($env:PATH -split ';')[0]
$capture.GeminiTitle = $Host.UI.RawUI.WindowTitle
$capture.OldMarker = Test-Path -LiteralPath $geminiExit
exit 17
'@
    Set-Content -LiteralPath (Join-Path $testDir 'ask-gemini.ps1') -Value @'
param([string]$Tema, [string]$Pregunta)
$capture.Research = @($Tema, $Pregunta) -join '|'
'@
    & $geminiLauncher -Script tool -Tarea prueba -MarkerDir $testDir -Programa nmap -Enfoque 'texto con espacios' -Actualizar
    Assert-Equal 'nmap|texto con espacios|True' $capture.Tool
    Assert-Equal 'Gemini - prueba' $capture.GeminiTitle
    Assert-Equal $true $capture.KeyLoaded
    Assert-Equal (Join-Path $env:APPDATA 'npm') $capture.PathFirst
    Assert-Equal $false $capture.OldMarker
    Assert-Marker $geminiExit 17
    & $geminiLauncher -Script research -Tarea prueba -MarkerDir $testDir -Args @('-Tema', 'ejemplo', '-Pregunta', '-literal')
    Assert-Equal 'ejemplo|-literal' $capture.Research
    Assert-Marker $geminiExit 0
    Write-Host 'Pruebas simuladas de ambos lanzadores OK.'
} finally {
    $Host.UI.RawUI.WindowTitle = $originalTitle
    $env:PATH = $originalPath
    $env:GEMINI_API_KEY = $originalKey
    Get-ChildItem -LiteralPath $testDir -File | Remove-Item
    Remove-Item -LiteralPath $testDir
}
