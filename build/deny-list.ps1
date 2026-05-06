# deny-list.ps1 — Shared deny-list module for build pipeline
# Exports: $script:DenyFiles, $script:DenyPatterns, Test-Denied, Test-DotDir, Test-DotFile
#
# NOTE: skill.index and skill.index.md are NEVER denied — the always-include
# guard is enforced in build.ps1, not here.
#
# This module is pure-data and has no config access.
# Workspace-level deny-extra additions are applied in build.ps1 after dot-sourcing.

$script:DenyFiles = [System.Collections.Generic.HashSet[string]]([System.StringComparer]::OrdinalIgnoreCase)
@(
    'spec.md'
    'uncompressed.md'
    '*.uncompressed.md'
    'instructions.uncompressed.md'
    'instructions.uncompressed.md.compressed'
    'optimize-log.md'
    'eval.md'
    'PLAN.md'
    'RESULTS.md'
) | ForEach-Object { [void]$script:DenyFiles.Add($_) }

# Wildcard patterns (evaluated per file via -like)
# *spec.md catches any file ending in spec.md regardless of separator (e.g. foo-spec.md, foo.spec.md, spec.md)
$script:DenyPatterns = @('*spec.md', '*.sha256')

function Test-Denied {
    param([System.IO.FileInfo]$File)
    if ($script:DenyFiles.Contains($File.Name)) { return $true }
    foreach ($pat in $script:DenyPatterns) {
        if ($File.Name -like $pat) { return $true }
    }
    return $false
}

function Test-DotDir {
    param([System.IO.DirectoryInfo]$Dir)
    return $Dir.Name.StartsWith('.')
}

# Edge 4: dot-prefixed filenames (e.g. .hidden, .env) are also denied
function Test-DotFile {
    param([System.IO.FileInfo]$File)
    return $File.Name.StartsWith('.')
}
