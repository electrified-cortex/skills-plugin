#Requires -Version 7
# scrub.ps1 -- mojibake / non-ASCII scrubber (detect + fix)
# Usage: scrub.ps1 <file_path|-> [--fix] [--stdout-only] [--ignore <CATEGORY>]... [--help]
# See scrub.spec.md for the full contract. Keep in sync with scrub.sh --
# both must produce byte-identical stdout for the same inputs.
#
# All output is written as raw UTF-8 bytes directly to the stdout stream
# (bypassing [Console]::Out) so behavior does not depend on the host's
# console code page / OutputEncoding default.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RawArgs
)

$ErrorActionPreference = 'Continue'

if ($null -eq $RawArgs) { $RawArgs = @() }

$StdoutStream = [Console]::OpenStandardOutput()
function Write-Out([string]$Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $StdoutStream.Write($bytes, 0, $bytes.Length)
}
function Exit-Clean([int]$Code) {
    $StdoutStream.Flush()
    exit $Code
}
function Fail([string]$Message) {
    Write-Out "ERROR: $Message`n"
    Exit-Clean 1
}

# -----------------------------------------------------------------------
# Help (checked first, anywhere in argv -- always wins)
# -----------------------------------------------------------------------
function Show-Usage {
    $usage = @'
Usage: scrub <file_path> [--fix] [--stdout-only] [--ignore <CATEGORY>]... [--help]

Detect and fix mojibake and non-ASCII punctuation (arrows, dashes, quotes,
ellipsis, bullets) in a text file. Detect-only by default.

Arguments:
  file_path             Absolute path to the file to scan, or - for stdin.

Flags:
  --fix                 Apply replacements in place. Default is detect-only.
  --stdout-only         Emit the fixed content to stdout without modifying
                         the source file. Mutually exclusive with --fix.
  --ignore <CATEGORY>   Skip a category. Repeatable; value may be a
                         comma-separated list. CATEGORY is one of:
                         mojibake, arrows, dashes, quotes, ellipsis, bullets.
  --help, -h            Print this usage and exit 0.

Output (stdout):
  CLEAN                    Detect mode: nothing to scrub.
  FINDINGS: <count>        Detect mode: followed by one line per finding:
                              <line>: <category>: '<original>' -> '<replacement>'
  FIXED: <count> replacements applied to <file_path>
                            --fix mode result.
  <transformed content>    --stdout-only mode: raw fixed content, no wrapper.
  ERROR: <reason>          Argument or runtime error.

Exit codes:
  0   Success (CLEAN, FINDINGS, FIXED, --stdout-only output, or --help).
  1   Error.
'@
    Write-Out $usage
    Write-Out "`n"
}

foreach ($a in $RawArgs) {
    if ($a -eq '--help' -or $a -eq '-h') {
        Show-Usage
        Exit-Clean 0
    }
}

# -----------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------
$FilePath = $null
$Fix = $false
$StdoutOnly = $false
$IgnoreCats = @()

$ValidCategories = @('mojibake', 'arrows', 'dashes', 'quotes', 'ellipsis', 'bullets')

$i = 0
while ($i -lt $RawArgs.Count) {
    $a = $RawArgs[$i]

    if ($a -eq '--fix') {
        $Fix = $true
        $i++
    }
    elseif ($a -eq '--stdout-only') {
        $StdoutOnly = $true
        $i++
    }
    elseif ($a -eq '--ignore') {
        if ($i + 1 -ge $RawArgs.Count) {
            Fail 'missing value for --ignore'
        }
        $val = $RawArgs[$i + 1]
        $parts = $val -split ','
        foreach ($c in $parts) {
            if ($ValidCategories -notcontains $c) {
                Fail "invalid category: $c"
            }
            $IgnoreCats += $c
        }
        $i += 2
    }
    elseif ($a.StartsWith('--')) {
        Fail "unknown argument: $a"
    }
    else {
        if ($null -ne $FilePath) {
            Fail "unexpected argument: $a"
        }
        $FilePath = $a
        $i++
    }
}

if ($null -eq $FilePath) {
    Fail 'missing required argument: file_path'
}

if ($Fix -and $StdoutOnly) {
    Fail '--fix and --stdout-only are mutually exclusive'
}

if ($FilePath -eq '-' -and $Fix) {
    Fail '--fix cannot be used with stdin input (use --stdout-only instead)'
}

if ($FilePath -ne '-') {
    $isAbsolute = $FilePath.StartsWith('/') -or `
        ($FilePath.Length -ge 2 -and [char]::IsLetter($FilePath[0]) -and $FilePath[1] -eq ':')
    if (-not $isAbsolute) {
        Fail "file_path must be an absolute path (or '-' for stdin): $FilePath"
    }
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Fail "file not found: $FilePath"
    }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        Fail "not a regular file: $FilePath"
    }
}

# -----------------------------------------------------------------------
# Read input (raw bytes -> UTF-8 text; bypasses any console code page)
# -----------------------------------------------------------------------
try {
    if ($FilePath -eq '-') {
        $stdinStream = [Console]::OpenStandardInput()
        $ms = New-Object System.IO.MemoryStream
        $stdinStream.CopyTo($ms)
        $bytes = $ms.ToArray()
    }
    else {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    }
    $content = [System.Text.Encoding]::UTF8.GetString($bytes)
}
catch {
    Fail "cannot read file: $FilePath"
}

# -----------------------------------------------------------------------
# Canonical replacement table -- keep in exact sync with scrub.sh.
# Patterns/replacements are built from explicit Unicode code points
# rather than literal characters: PowerShell's tokenizer treats curly
# quotes (U+2018/2019/201C/201D) as smart-quote equivalents of ' and ",
# so embedding them as literal string delimiters breaks parsing.
# Order matters: mojibake sequences are matched/replaced before the
# categories below so a mojibake sequence is never double-counted as a
# plain quote/dash/etc once its trailing byte happens to render as one.
# See scrub.spec.md for the full table with rationale.
# -----------------------------------------------------------------------
function ConvertFrom-CodePoints {
    param([int[]]$CodePoints)
    if ($CodePoints.Count -eq 0) { return '' }
    -join ($CodePoints | ForEach-Object { [char]::ConvertFromUtf32($_) })
}

$Categories = @(
    'mojibake', 'mojibake', 'mojibake', 'mojibake', 'mojibake', 'mojibake', 'mojibake', 'mojibake',
    'arrows', 'arrows', 'arrows', 'arrows', 'arrows', 'arrows', 'arrows', 'arrows',
    'dashes', 'dashes',
    'quotes', 'quotes', 'quotes', 'quotes',
    'ellipsis',
    'bullets', 'bullets', 'bullets', 'bullets', 'bullets', 'bullets'
)
$AutoFixes = @(
    $true, $true, $true, $true, $true, $true, $true, $false,
    $true, $true, $true, $true, $true, $true, $true, $true,
    $true, $true,
    $true, $true, $true, $true,
    $true,
    $true, $true, $true, $true, $true, $true
)
$PatternCodePoints = @(
    @(0x00E2, 0x20AC, 0x2122), @(0x00E2, 0x20AC, 0x02DC), @(0x00E2, 0x20AC, 0x0153),
    @(0x00E2, 0x20AC, 0x201C), @(0x00E2, 0x20AC, 0x201D), @(0x00E2, 0x20AC, 0x00A2),
    @(0x00E2, 0x20AC, 0x00A6), @(0x00C2, 0x0020),
    @(0x2192), @(0x2190), @(0x2191), @(0x2193), @(0x2194), @(0x21D2), @(0x21D0), @(0x21D4),
    @(0x2014), @(0x2013),
    @(0x2018), @(0x2019), @(0x201C), @(0x201D),
    @(0x2026),
    @(0x2022), @(0x25E6), @(0x2023), @(0x25CF), @(0x25AA), @(0x25AB)
)
$ReplaceCodePoints = @(
    @(0x0027), @(0x0027), @(0x0022),
    @(0x002D), @(0x002D, 0x002D), @(0x002D),
    @(0x002E, 0x002E, 0x002E), @(),
    @(0x002D, 0x003E), @(0x003C, 0x002D), @(0x005E), @(0x0076), @(0x003C, 0x002D, 0x003E),
    @(0x003D, 0x003E), @(0x003C, 0x003D), @(0x003C, 0x003D, 0x003E),
    @(0x002D, 0x002D), @(0x002D),
    @(0x0027), @(0x0027), @(0x0022), @(0x0022),
    @(0x002E, 0x002E, 0x002E),
    @(0x002D), @(0x002D), @(0x002D), @(0x002D), @(0x002D), @(0x002D)
)
$Patterns = @($PatternCodePoints | ForEach-Object { ConvertFrom-CodePoints $_ })
$Replaces = @($ReplaceCodePoints | ForEach-Object { ConvertFrom-CodePoints $_ })
$ManualMarker = '(manual review -- no safe auto-fix)'

function Count-Occurrences([string]$Line, [string]$Pattern) {
    if ([string]::IsNullOrEmpty($Pattern)) { return 0 }
    $occCount = 0
    $searchIdx = 0
    while (($searchIdx = $Line.IndexOf($Pattern, $searchIdx, [System.StringComparison]::Ordinal)) -ge 0) {
        $occCount++
        $searchIdx += $Pattern.Length
    }
    return $occCount
}

# -----------------------------------------------------------------------
# Scan + replace, one pattern at a time, in table order.
# -----------------------------------------------------------------------
$findings = [System.Collections.Generic.List[object]]::new()
$totalFixCount = 0

for ($idx = 0; $idx -lt $Patterns.Count; $idx++) {
    $pat = $Patterns[$idx]
    $rep = $Replaces[$idx]
    $cat = $Categories[$idx]
    $af = $AutoFixes[$idx]

    if ($IgnoreCats -contains $cat) { continue }

    $lines = $content -split "`n"
    $matchCount = 0
    $dispRep = if ($af) { $rep } else { $ManualMarker }

    for ($li = 0; $li -lt $lines.Count; $li++) {
        $occ = Count-Occurrences $lines[$li] $pat
        if ($occ -gt 0) {
            $matchCount += $occ
            $lineNo = $li + 1
            $text = "$lineNo" + ': ' + $cat + ": '" + $pat + "' -> '" + $dispRep + "'"
            for ($k = 0; $k -lt $occ; $k++) {
                $findings.Add([PSCustomObject]@{ Line = $lineNo; Idx = $idx; Text = $text })
            }
        }
    }

    if ($af -and $matchCount -gt 0) {
        $totalFixCount += $matchCount
        $content = $content.Replace($pat, $rep)
    }
}

$totalFindingCount = $findings.Count

# -----------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------
if ($StdoutOnly) {
    Write-Out $content
    Exit-Clean 0
}

if ($Fix) {
    if ($totalFixCount -gt 0) {
        try {
            [System.IO.File]::WriteAllBytes($FilePath, [System.Text.Encoding]::UTF8.GetBytes($content))
        }
        catch {
            Fail "failed to write file: $FilePath"
        }
    }
    Write-Out "FIXED: $totalFixCount replacements applied to $FilePath`n"
    Exit-Clean 0
}

if ($totalFindingCount -eq 0) {
    Write-Out "CLEAN`n"
    Exit-Clean 0
}

Write-Out "FINDINGS: $totalFindingCount`n"
$sorted = $findings | Sort-Object -Property Line, Idx
foreach ($f in $sorted) {
    Write-Out ($f.Text + "`n")
}
Exit-Clean 0
