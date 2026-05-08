#Requires -Version 7
<#
.SYNOPSIS
    Drain all pending messages from an agent's inbox.
.DESCRIPTION
    Collects all unclaimed messages, claims each exclusively, reads it, archives it,
    and outputs the content to stdout. Returns all pending messages in one invocation.
    See drain.spec.md for full specification.
.PARAMETER Inbox
    Agent name whose inbox to drain (kebab-case).
.PARAMETER Workspace
    Workspace root path. Defaults to current directory.
#>
[CmdletBinding()]
param(
    [Parameter()][string]$Inbox,
    [Parameter()][string]$Workspace = $PWD,
    [Parameter()][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

if (-not $Inbox) {
    [Console]::Error.WriteLine('Missing required argument: --inbox')
    exit 1
}

# Resolve paths
$inboxDir   = Join-Path $Workspace '.inbox' $Inbox
$archiveDir = Join-Path $inboxDir 'archive'

# Empty inbox is not an error
if (-not (Test-Path $inboxDir)) {
    exit 0
}

# Ensure archive dir exists
if (-not (Test-Path $archiveDir)) {
    try {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    } catch {
        [Console]::Error.WriteLine("Failed to create archive directory '$archiveDir': $_")
        exit 2
    }
}

# Helper: archive a claimed file, collect JSON content, handle errors
function Drain-ClaimedFile {
    param([string]$ClaimedPath, [string]$OrigName, [bool]$OutputContent, [System.Collections.Generic.List[string]]$Messages)
    $archiveDest = Join-Path $archiveDir $OrigName
    $content = $null
    try {
        $content = Get-Content -Path $ClaimedPath -Raw -Encoding UTF8
    } catch {
        [Console]::Error.WriteLine("Failed to read '$ClaimedPath': $_")
    }
    try {
        Move-Item -Path $ClaimedPath -Destination $archiveDest -Force
    } catch {
        [Console]::Error.WriteLine("Failed to archive '$ClaimedPath' to '$archiveDest': $_")
    }
    if ($OutputContent -and $null -ne $content) {
        $Messages.Add($content.Trim())
    }
}

# Pass 1: unclaimed *.json files (sorted ascending)
$msgFiles = Get-ChildItem -Path $inboxDir -Filter '*.json' -File |
    Sort-Object Name

$messages = [System.Collections.Generic.List[string]]::new()

foreach ($file in $msgFiles) {
    $claimedPath = "$($file.FullName).claimed"
    try {
        Move-Item -Path $file.FullName -Destination $claimedPath -ErrorAction Stop
    } catch {
        continue
    }
    Drain-ClaimedFile -ClaimedPath $claimedPath -OrigName $file.Name -OutputContent $true -Messages $messages
}

# Pass 2: leftover *.json.claimed from a prior crashed run — archive without re-outputting
$claimedFiles = Get-ChildItem -Path $inboxDir -Filter '*.json.claimed' -File |
    Sort-Object Name

foreach ($file in $claimedFiles) {
    $origName = $file.Name -replace '\.claimed$', ''
    Drain-ClaimedFile -ClaimedPath $file.FullName -OrigName $origName -OutputContent $false -Messages $messages
}

# Output JSON array
Write-Output "[$($messages -join ',')]"

exit 0
