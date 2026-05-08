#Requires -Version 7
<#
.SYNOPSIS
    Post a message to another agent's inbox.
.DESCRIPTION
    Atomically writes a message file into the recipient's inbox and writes the signal file.
    See post.spec.md for full specification.
.PARAMETER From
    Posting agent's canonical name (kebab-case).
.PARAMETER To
    Recipient agent's canonical name (kebab-case).
.PARAMETER Subject
    Short description of message intent.
.PARAMETER Body
    Message body text.
.PARAMETER Workspace
    Workspace root path. Defaults to current directory.
#>
[CmdletBinding()]
param(
    [Parameter()][string]$From,
    [Parameter()][string]$To,
    [Parameter()][string]$Subject,
    [Parameter()][string]$Body,
    [Parameter()][string]$Workspace = $PWD,
    [Parameter()][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

# Validate required args
$missing = @()
if (-not $From) { $missing += '--from' }
if (-not $To)   { $missing += '--to' }
if (-not $Body) { $missing += '--body' }
if ($missing.Count -gt 0) {
    [Console]::Error.WriteLine("Missing required argument(s): $($missing -join ', ')")
    exit 1
}

if ($From -eq $To) {
    [Console]::Error.WriteLine("Cannot post to own inbox: --from and --to are both '$From'")
    exit 1
}

# Resolve paths
$inboxDir  = Join-Path $Workspace '.inbox' $To
$archiveDir = Join-Path $inboxDir 'archive'
$signalPath = Join-Path $inboxDir '.signal'

# Ensure inbox and archive directories exist
try {
    if (-not (Test-Path $inboxDir))   { New-Item -ItemType Directory -Path $inboxDir   -Force | Out-Null }
    if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null }
} catch {
    [Console]::Error.WriteLine("Failed to create inbox directory '$inboxDir': $_")
    exit 2
}

# Generate timestamp
$ts       = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$tsFull   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

# Generate CSPRNG nonce (8 hex chars) with collision retry
$maxRetries = 10
$msgPath = $null
for ($i = 0; $i -lt $maxRetries; $i++) {
    $bytes = [byte[]]::new(4)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $nonce = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    $filename = "${ts}-${nonce}.json"
    $candidate = Join-Path $inboxDir $filename
    if (-not (Test-Path $candidate)) {
        $msgPath = $candidate
        break
    }
}
if (-not $msgPath) {
    [Console]::Error.WriteLine("Failed to generate unique filename after $maxRetries attempts")
    exit 2
}

# Assemble JSON message
$msg = [ordered]@{ from = $From; sent = $tsFull }
if ($Subject) { $msg['subject'] = $Subject }
$msg['body'] = $Body
$content = $msg | ConvertTo-Json -Compress

# Atomic write: temp file outside inbox, then rename into inbox
try {
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $content -Encoding UTF8 -NoNewline
    Move-Item -Path $tmp -Destination $msgPath -Force
} catch {
    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    [Console]::Error.WriteLine("Failed to write message file: $_")
    exit 2
}

# Write signal file (failure tolerated)
try {
    Set-Content -Path $signalPath -Value $ts -Encoding UTF8 -Force
} catch {
    # Signal write failure is non-fatal — message is already in inbox
}

exit 0
