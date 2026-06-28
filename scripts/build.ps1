# Build kenlm as static, self-contained binaries. Windows (MSVC + vcpkg static triplet).
# Requires vcpkg: set $env:VCPKG_ROOT and (optionally) $env:VCPKG_TARGET_TRIPLET.
$ErrorActionPreference = 'Stop'

$Root       = Split-Path -Parent $PSScriptRoot
$KenlmSrc   = Join-Path $Root 'upstream\kenlm'

if (-not (Test-Path (Join-Path $KenlmSrc 'CMakeLists.txt'))) {
    throw "kenlm source not found at $KenlmSrc"
}

$Triplet = $env:VCPKG_TARGET_TRIPLET
if (-not $Triplet) {
    $arch  = if ($env:PROCESSOR_ARCHITECTURE -match 'ARM') { 'arm64' } else { 'x64' }
    $Triplet = "$arch-windows-static"
}
$Toolchain = Join-Path $env:VCPKG_ROOT 'scripts\buildsystems\vcpkg.cmake'
if (-not (Test-Path $Toolchain)) {
    throw "vcpkg.cmake not found at $Toolchain (set VCPKG_ROOT to your vcpkg checkout)"
}

# Header-only boost_system shim (modern Boost ships no compiled system lib).
$Shim = (Join-Path $Root 'cmake') -replace '\\', '/'

Write-Host "==> cmake configure (triplet=$Triplet)"
cmake -S $KenlmSrc -B build -DCMAKE_BUILD_TYPE=Release `
    -DFORCE_STATIC=ON -DBoost_USE_STATIC_LIBS=ON `
    -DCMAKE_PREFIX_PATH="$Shim" `
    -DCMAKE_TOOLCHAIN_FILE=$Toolchain -DVCPKG_TARGET_TRIPLET=$Triplet

Write-Host '==> cmake --build'
cmake --build build --config Release -j

Write-Host '==> built binaries:'
Get-ChildItem build\bin\Release\*.exe | Select-Object -ExpandProperty Name
