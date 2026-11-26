$ErrorActionPreference = 'Stop'

$lanzados = @()
$presentes = @()
$pendientes = @('gemini', 'codex')
$motivo = ''

try {
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    $root = Split-Path -Parent $PSScriptRoot
    Write-Output '# Contexto del proyecto (cargado por hook)'
    foreach ($ruta in @('docs/COMMON_CONTEXT.md', 'claude/CONTEXT.md', 'docs/PRODUCT_BRIEF.md', 'docs/DECISIONS.md')) {
        Write-Output "`n## $ruta"
        $archivo = Join-Path $root $ruta
        try {
            if (Test-Path -LiteralPath $archivo -PathType Leaf) {
                Get-Content -LiteralPath $archivo -Raw -Encoding UTF8
            } else {
                Write-Output '(Archivo faltante)'
            }
        } catch {
            Write-Output "(Error al leer el archivo: $($_.Exception.Message))"
        }
    }

    $evento = ConvertFrom-Json -InputObject ([Console]::In.ReadToEnd())
    if ($evento.source -ne 'startup') {
        $motivo = "evento distinto de startup ($($evento.source))"
    } elseif ($env:HACKATON_NO_AUTOSTART -eq '1') {
        $motivo = 'HACKATON_NO_AUTOSTART=1'
    } elseif ($env:HACKATON_AGENTS_LAUNCHED -eq '1') {
        $motivo = 'HACKATON_AGENTS_LAUNCHED=1'
    } else {
        # Serialize checks for concurrent Claude startups in this project.
        $mutexName = 'Local\HackatonClaudeStart:' + $root.ToUpperInvariant().Replace('\', '/')
        $mutex = [Threading.Mutex]::new($false, $mutexName)
        $locked = $false
        try {
            try {
                $locked = $mutex.WaitOne(0)
            } catch [Threading.AbandonedMutexException] {
                $locked = $true
            }

            if (-not $locked) {
                $motivo = 'otro inicio de Claude ya coordina la apertura'
            } else {
                $launcher = Join-Path $PSScriptRoot 'start-agents.ps1'
                $launcherArgument = $launcher.Replace("'", "''")
                # Match the absolute project path and include launchers still opening agent terminals.
                $patron = '(?:' + [regex]::Escape($launcher) + '|' + [regex]::Escape($launcherArgument) +
                    ')[\x27"]?\s+-Agentes?\s+[\x27"]?(?<agents>(?:gemini|codex)(?:,(?:gemini|codex))*)(?=[\x27"\s]|$)'
                $procesos = Get-CimInstance -ClassName Win32_Process -Filter "CommandLine LIKE '%start-agents.ps1%'" -OperationTimeoutSec 1
                $activos = foreach ($proceso in $procesos) {
                    if ($proceso.CommandLine -match $patron) {
                        $Matches.agents -split ','
                    }
                }
                $presentes = @($pendientes | Where-Object { $_ -in $activos })
                $pendientes = @($pendientes | Where-Object { $_ -notin $presentes })

                if ($pendientes.Count) {
                    # -Command preserves the PowerShell array syntax for -Agentes.
                    $comando = "& '$launcherArgument' -Agentes $($pendientes -join ',')"
                    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
                        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ('"' + $comando + '"')
                    ) -WorkingDirectory $root -WindowStyle Hidden
                    $lanzados = $pendientes
                    $pendientes = @()
                }
            }
        } finally {
            if ($locked) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    }
} catch {
    $motivo = "error del hook ($($_.Exception.Message -replace '\s+', ' '))"
}

$estado = 'Estado de agentes'
if ($lanzados.Count) { $estado += " | apertura solicitada: $($lanzados -join ', ')" }
if ($presentes.Count) { $estado += " | activos o en apertura: $($presentes -join ', ')" }
if ($pendientes.Count) { $estado += " | omitidos: $($pendientes -join ', ') ($motivo)" }
Write-Output "`n$estado"
exit 0
