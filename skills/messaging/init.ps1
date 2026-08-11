#Requires -Version 7
<#
.SYNOPSIS
    Register an agent's identity in the shared inbox space.
.DESCRIPTION
    Creates the agent's inbox directory, archive subdirectory, and signal file.
    Fails with exit code 2 if the name is already taken (unless --force is set).
    See init.spec.md for full specification.
.PARAMETER Name
    Agent's canonical name to register (kebab-case).
.PARAMETER Workspace
    Workspace root path. Defaults to current directory.
.PARAMETER Force
    Reclaim an existing inbox (for agent restart). Never fails due to pre-existing inbox.
    Does not modify existing messages.
#>
[CmdletBinding()]
param(
    [Parameter()][string]$Name,
    [Parameter()][string]$Workspace = $PWD,
    [Parameter()][switch]$Force,
    [Parameter()][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

if (-not $Name) {
    [Console]::Error.WriteLine('Missing required argument: --name')
    exit 1
}

$inboxDir   = Join-Path $Workspace '.inbox' $Name
$archiveDir = Join-Path $inboxDir 'archive'
$signalPath = Join-Path $inboxDir '.signal'

if (-not $Force) {
    # Atomic name claim: fail if already exists
    if (Test-Path $inboxDir) {
        [Console]::Error.WriteLine("inbox '$Name' is already registered")
        exit 2
    }
    try {
        New-Item -ItemType Directory -Path $inboxDir | Out-Null
    } catch {
        if (Test-Path $inboxDir) {
            [Console]::Error.WriteLine("inbox '$Name' is already registered")
            exit 2
        }
        [Console]::Error.WriteLine("Failed to create inbox directory '$inboxDir': $_")
        exit 3
    }
} else {
    # --force: create if missing, skip if present
    if (-not (Test-Path $inboxDir)) {
        try {
            New-Item -ItemType Directory -Path $inboxDir -Force | Out-Null
        } catch {
            [Console]::Error.WriteLine("Failed to create inbox directory '$inboxDir': $_")
            exit 3
        }
    }
}

# Ensure archive directory exists
try {
    if (-not (Test-Path $archiveDir)) {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    }
} catch {
    [Console]::Error.WriteLine("Failed to create archive directory '$archiveDir': $_")
    exit 3
}

# Write signal file (required on init — watcher cannot attach without it)
try {
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Set-Content -Path $signalPath -Value $ts -Encoding UTF8 -Force
} catch {
    [Console]::Error.WriteLine("Failed to write signal file '$signalPath': $_")
    exit 3
}

exit 0
