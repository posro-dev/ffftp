# POSRO FFFTP v5.8 build and launch; PowerShell 5.1 compatible (ASCII).
[CmdletBinding()]
param([switch]$NoBuild)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$branch = 'fix/ftpes-close-notify-v58'
$exe = Join-Path $repo 'Release\x64\ffftp.exe'
$mui = Join-Path $repo 'Release\x64\ja-JP\ffftp.exe.mui'
$profileDir = Join-Path $env:LOCALAPPDATA 'Posro\FFFTP-v58'
$ini = Join-Path $profileDir 'ffftp.ini'

if (-not (Test-Path (Join-Path $repo 'ffftp.vcxproj') -PathType Leaf)) {
    throw 'FFFTP project not found. Run this from the repository root.'
}
$git = (Get-Command git.exe -ErrorAction Stop).Source
$current = (& $git -C $repo branch --show-current)
if ($LASTEXITCODE -ne 0 -or $current.Trim() -ne $branch) {
    throw "Expected branch $branch; found $current"
}
$changes = @(& $git -C $repo status --porcelain -uno)
if ($LASTEXITCODE -ne 0 -or $changes.Count -gt 0) {
    throw 'Tracked source files have uncommitted changes. No build started.'
}

if (-not $NoBuild) {
    $running = @(Get-CimInstance Win32_Process -Filter "Name='ffftp.exe'" |
        Where-Object { $_.ExecutablePath -eq $exe })
    if ($running.Count -gt 0) {
        throw 'Close the POSRO branch build of FFFTP before rebuilding.'
    }
    $msbuild = Join-Path $env:ProgramFiles 'Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'
    if (-not (Test-Path $msbuild -PathType Leaf)) {
        throw "MSBuild was not found: $msbuild"
    }
    Write-Host '[1/2] Build FFFTP v5.8 Release x64...'
    & $msbuild (Join-Path $repo 'ffftp.vcxproj') /m /p:Configuration=Release /p:Platform=x64 /p:RunCodeAnalysis=false /verbosity:minimal
    if ($LASTEXITCODE -ne 0) { throw 'MSBuild failed; FFFTP will not start.' }
}

if (-not (Test-Path $exe -PathType Leaf)) { throw "Missing EXE: $exe" }
if (-not (Test-Path $mui -PathType Leaf)) {
    throw "Missing Japanese MUI: $mui"
}
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
Write-Host '[2/2] Launch isolated FFFTP...'
Write-Host "EXE: $exe"
Write-Host "INI: $ini"
Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) -ArgumentList @('--ini', ('"{0}"' -f $ini))
