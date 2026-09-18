param(
    [string]$Manifest = "$PSScriptRoot/m2-generation-manifest.json",
    [string[]]$Assets = @()
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$data = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
foreach ($asset in $data.assets) {
    if ($Assets.Count -gt 0 -and $asset.asset -notin $Assets) {
        continue
    }
    $target = Join-Path $root $asset.path
    $directory = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    Invoke-WebRequest -Uri $asset.url -OutFile $target
    if ((Get-Item -LiteralPath $target).Length -eq 0) {
        throw "Downloaded zero-byte asset: $($asset.asset)"
    }
    Write-Output "$($asset.asset): $target"
}
