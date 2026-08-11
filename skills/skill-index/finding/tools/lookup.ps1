param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Query
)

# Normalize query to cache key
$key = $Query.ToLower()
$key = $key -replace '[/\\_\s]+', '-'
$key = $key -replace '[^a-z0-9-]', ''
$key = $key.Trim('-')

# Ensure cache directory and file exist
$cacheDir  = Join-Path $Root '.skill-index'
$cacheFile = Join-Path $cacheDir 'lookup.cache'

if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}
if (-not (Test-Path $cacheFile)) {
    New-Item -ItemType File -Path $cacheFile -Force | Out-Null
    Write-Output 'miss'
    exit 0
}

# Grep-style single-line lookup — agent never reads the full file
$match = Select-String -LiteralPath $cacheFile -Pattern "^${key}:" | Select-Object -First 1
if (-not $match) {
    Write-Output 'miss'
    exit 0
}

$value = ($match.Line -split ':\s*', 2)[1].Trim()

if ($value -match '^https?://') {
    Write-Output "url: $value"
    exit 0
}

if (Test-Path -LiteralPath $value) {
    Write-Output "hit: $value"
} else {
    Write-Output "stale: $value"
}
