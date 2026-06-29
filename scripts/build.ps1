# Build kenlm as static, self-contained binaries. Windows (MSVC + vcpkg static triplet).
# Requires vcpkg: VCPKG_ROOT set (the CI install-deps step exports it), and
# optionally VCPKG_TARGET_TRIPLET.
$ErrorActionPreference = 'Stop'

$Root     = Split-Path -Parent $PSScriptRoot
$KenlmSrc = Join-Path $Root 'upstream\kenlm'

if (-not (Test-Path (Join-Path $KenlmSrc 'CMakeLists.txt'))) {
    throw "kenlm source not found at $KenlmSrc"
}

$Triplet = $env:VCPKG_TARGET_TRIPLET
if (-not $Triplet) {
    $arch   = if ($env:PROCESSOR_ARCHITECTURE -match 'ARM') { 'arm64' } else { 'x64' }
    $Triplet = "$arch-windows-static"
}
if (-not $env:VCPKG_ROOT) {
    throw 'VCPKG_ROOT is not set (the install-deps step should export it via GITHUB_ENV)'
}
$Toolchain = Join-Path $env:VCPKG_ROOT 'scripts\buildsystems\vcpkg.cmake'
if (-not (Test-Path $Toolchain)) {
    throw "vcpkg.cmake not found at $Toolchain"
}

# Header-only boost_system shim (modern Boost ships no compiled system lib).
$Shim = (Join-Path $Root 'cmake') -replace '\\', '/'

# Hand args to cmake.exe via an array (splatting). Do NOT use backtick
# line-continuation here: it breaks when the script is checked out with CRLF,
# leaving variables unexpanded for the native command.
$cmakeArgs = @(
    '-S', $KenlmSrc,
    '-B', 'build',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DFORCE_STATIC=ON',
    '-DBoost_USE_STATIC_LIBS=ON',
    "-DCMAKE_PREFIX_PATH=$Shim",
    "-DCMAKE_TOOLCHAIN_FILE=$Toolchain",
    "-DVCPKG_TARGET_TRIPLET=$Triplet"
)

Write-Host "==> cmake configure (triplet=$Triplet)"
& cmake @cmakeArgs

Write-Host '==> cmake --build'
& cmake --build build --config Release -j

Write-Host '==> built binaries:'
Get-ChildItem build\bin\Release\*.exe | Select-Object -ExpandProperty Name
