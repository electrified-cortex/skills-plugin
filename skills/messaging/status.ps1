#Requires -Version 7
<#
.SYNOPSIS
    Report the number of pending messages in an agent's inbox.
.DESCRIPTION
    Lightweight read-only probe. Counts unclaimed message files and outputs the pending
    count. Does not claim, read, or modify any file. Intended as a Monitor callback.
    See status.spec.md for full specification.
.PARAMETER Inbox
    Agent name whose inbox to check (kebab-case).
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

$inboxDir = Join-Path $Workspace '.inbox' $Inbox

$count = 0
if (Test-Path $inboxDir) {
    try {
        $count = (Get-ChildItem -Path $inboxDir -Filter '*.json' -File |
            Measure-Object).Count
    } catch {
        [Console]::Error.WriteLine("Failed to read inbox directory '$inboxDir': $_")
        exit 2
    }
}

$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Write-Output "[${ts}]: ${count} messages waiting"

exit 0
