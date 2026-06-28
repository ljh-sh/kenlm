# Stage the built binaries into a self-contained zip. Windows.
#   $env:TARGET  e.g. x86_64-windows | aarch64-windows
$ErrorActionPreference = 'Stop'

$Root   = Split-Path -Parent $PSScriptRoot
$Dist   = if ($env:DIST) { $env:DIST } else { Join-Path $Root 'dist' }
$Target = $env:TARGET
if (-not $Target) { throw 'set $env:TARGET, e.g. x86_64-windows' }

$Stage   = Join-Path $Dist "kenlm-$Target"
$BinSrc  = Join-Path $Root 'build\bin\Release'
$Binaries = 'lmplz','build_binary','query','filter'

if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path "$Stage\bin" | Out-Null

foreach ($b in $Binaries) {
    $src = Join-Path $BinSrc "$b.exe"
    if (-not (Test-Path $src)) { throw "$src not built" }
    Copy-Item $src (Join-Path $Stage 'bin')
}

# /MT + static vcpkg triplets => no runtime DLLs to bundle.
$zip = Join-Path $Dist "kenlm-$Target.zip"
Compress-Archive -Path "$Stage\bin" -DestinationPath $zip -Force

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
"$hash  kenlm-$Target.zip" | Set-Content -Encoding ascii "$zip.sha256"

Write-Host "==> $zip"
