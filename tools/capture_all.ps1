<#
.SYNOPSIS
    Re-shoots every screenshot set against the current build.

.DESCRIPTION
    The captures in tests/results/screenshots are evidence, and evidence goes
    stale the moment the thing it photographs changes. There was no single way
    to refresh them, so sets drifted out of date at different rates and old
    photographs kept surviving into the README. This runs every capture scene
    in one pass and deletes the isolated session_<pid> folders the tools leave
    behind, which are per-run save sandboxes and must never be committed.

    Run it after any change to the UI, the floors or the cabinet art, and
    commit the result as its own commit.

.PARAMETER Only
    Shoot just the named sets, e.g. -Only menu,core_overclock. Names are the
    keys in $Sets below.

.PARAMETER Godot
    Path to the Godot console binary.

.EXAMPLE
    pwsh tools/capture_all.ps1
    pwsh tools/capture_all.ps1 -Only menu,core_overclock,poker
#>
[CmdletBinding()]
param(
    [string[]]$Only,
    [string]$Godot = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe'
)

# Stop on a genuine cmdlet failure, but see the note by the Godot call: a
# native exe writing to stderr is not a failure.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

# Scene, plus the extra user args that scene wants. Order is deliberate: the
# cheap ones first, so a broken build is obvious in seconds rather than minutes.
$Sets = [ordered]@{
    menu            = @{ scene = 'tools/capture_menu.tscn';            args = @('--capture-size=1920x1080') }
    core_overclock  = @{ scene = 'tools/capture_core_overclock.tscn';  args = @('--capture-dir=core_overclock_fhd', '--capture-size=1920x1080') }
    upgrade_cluster = @{ scene = 'tools/capture_upgrade_cluster.tscn'; args = @('--capture-dir=upgrade_cluster_fhd', '--capture-size=1920x1080') }
    poker           = @{ scene = 'tools/capture_poker.tscn';           args = @('--capture-dir=poker_fhd', '--capture-size=1920x1080') }
    baccarat        = @{ scene = 'tools/capture_baccarat.tscn';        args = @('--capture-dir=baccarat_fhd', '--capture-size=1920x1080') }
    match_point     = @{ scene = 'tools/capture_match_point.tscn';     args = @('--capture-dir=match_point_fhd', '--capture-size=1920x1080') }
    roulette        = @{ scene = 'tools/capture_roulette.tscn';        args = @('--capture-dir=roulette_fhd', '--capture-size=1920x1080') }
    floor           = @{ scene = 'tools/capture_floor.tscn';           args = @('--capture-size=1920x1080') }
    deck            = @{ scene = 'tools/capture_deck.tscn';            args = @('--capture-size=1920x1080') }
    office          = @{ scene = 'tools/capture_office.tscn';          args = @('--capture-dir=office_fhd', '--capture-size=1920x1080') }
    dev_menu        = @{ scene = 'tools/capture_dev_menu.tscn';        args = @('--capture-size=1920x1080') }
    game            = @{ scene = 'tools/capture_game.tscn';            args = @('--capture-size=1920x1080') }
}

$names = if ($Only) { $Only } else { $Sets.Keys }

if (-not (Test-Path $Godot)) { throw "Godot not found at $Godot" }

Write-Host '== importing ==' -ForegroundColor Cyan
& $Godot --headless --path . --import | Out-Null

$failed = @()
foreach ($name in $names) {
    if (-not $Sets.Contains($name)) { throw "Unknown capture set '$name'. Known: $($Sets.Keys -join ', ')" }
    $set = $Sets[$name]
    Write-Host "== $name ==" -ForegroundColor Cyan
    # No 2>&1 here. In Windows PowerShell 5.1 redirecting a native executable's
    # stderr wraps each line in a NativeCommandError, which under
    # $ErrorActionPreference = 'Stop' aborts the whole run on a harmless warning.
    # Godot prints its script errors to stdout, which is what we grade on.
    $output = & $Godot --path . $set.scene -- @($set.args) | Out-String
    $shots = ([regex]::Matches($output, 'SCREENSHOT ')).Count
    if ($output -match 'SCRIPT ERROR' -or $shots -eq 0) {
        $failed += $name
        Write-Host "   FAILED ($shots shots)" -ForegroundColor Red
        ($output -split "`n" | Select-String 'SCRIPT ERROR' | Select-Object -First 3) | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    } else {
        Write-Host "   $shots shots" -ForegroundColor Green
    }
}

# Each capture tool isolates its saves in a session_<pid> folder beside its
# output. They are sandboxes, not evidence, and committing them has happened.
Write-Host '== cleaning session sandboxes ==' -ForegroundColor Cyan
Get-ChildItem tests/results/screenshots -Recurse -Directory -Filter 'session_*' |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force; Write-Host "   removed $($_.Name)" }

Pop-Location

if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host 'All capture sets refreshed.' -ForegroundColor Green
