param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][string]$Value
)

$cacheDir  = Join-Path $Root '.skill-index'
$cacheFile = Join-Path $cacheDir 'lookup.cache'

if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}
if (-not (Test-Path $cacheFile)) {
    New-Item -ItemType File -Path $cacheFile -Force | Out-Null
}

$newLine = "${Key}: ${Value}"
$lines   = @(Get-Content -LiteralPath $cacheFile)
$updated = $false
$result  = @()

foreach ($line in $lines) {
    if ($line -match "^${Key}:") {
        $result += $newLine
        $updated = $true
    } else {
        $result += $line
    }
}

if (-not $updated) {
    $result += $newLine
}

$result | Set-Content -LiteralPath $cacheFile
