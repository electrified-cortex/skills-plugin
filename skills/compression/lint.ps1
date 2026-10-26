#Requires -Version 7
# lint.ps1 -- deterministic compression lint (detect-only) and fix-contract check
# Usage: lint.ps1 <file> <full|ultra>
#        lint.ps1 --check <src> <dst> <full|ultra>
#   <file>, <src>, <dst>  path to a readable regular file (relative or absolute)
#   <full|ultra>          compression tier; lite and none are not linted
# Output (plain text, LF): lint mode prints one finding per line, "line N: <rule>",
#   and nothing when the file is clean. --check prints one "reject: ..." line per
#   violation and nothing when the fix is accepted.
# Exit: 0 clean or accepted, 1 findings or rejected, 2 usage error or a lint regex
#   that does not compile (stderr only, nothing on stdout).
# See lint.spec.md for the full contract. Keep in sync with lint.sh -- both must
# print the same stdout and exit with the same code for the same inputs.
# Safety: an argument is only ever a file path or a tier word. Nothing is
# evaluated or executed from an argument, and no file is ever modified.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RawArgs
)

$ErrorActionPreference = 'Stop'

if ($null -eq $RawArgs) { $RawArgs = @() }

# Invariant culture, so case-insensitive matching never depends on the host locale.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

# All stdout is written as raw bytes with LF line endings (no host newline, no BOM).
$StdoutStream = [Console]::OpenStandardOutput()
function Write-Out([string]$Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $StdoutStream.Write($bytes, 0, $bytes.Length)
}
function Exit-With([int]$Code) {
    $StdoutStream.Flush()
    exit $Code
}

# Exit-Usage <message>: usage error, message on stderr, nothing on stdout, exit 2.
function Exit-Usage([string]$Message) {
    [Console]::Error.Write("usage: $Message`n")
    Exit-With 2
}

# -----------------------------------------------------------------------
# The five lint rules (.NET regex, ECMAScript option: ASCII-only \b and \s,
# like lint.sh, which matches bytes). The JavaScript reference differs on \s:
# there it is Unicode and also matches the no-break space, the byte order mark
# and the U+2000 spaces. Keep in exact sync with lint.sh and with
# lint.spec.md. Rules 1 and 2 are case-insensitive, rule 3 is case-sensitive
# (its regex spells out the capitals), rules 4 and 5 are ultra only.
# Rule 1 has an allow-list: the idiom "at a time" is replaced by the placeholder
# at_time before the rule matches (see Get-Findings); it is never printed.
# The regexes are built once, here, inside try/catch: that is this port's probe.
# One that does not compile ends the run as a usage error (exit 2, nothing on
# stdout), never as a clean result.
# -----------------------------------------------------------------------
$RxCI = [System.Text.RegularExpressions.RegexOptions]::ECMAScript -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
$RxCS = [System.Text.RegularExpressions.RegexOptions]::ECMAScript
try {
    $ReArticle = [regex]::new('\b(a|an|the)\b', $RxCI)
    $ReAtTime = [regex]::new('\bat a time\b', $RxCI)
    $ReFiller = [regex]::new('\b(simply|really|basically|actually|essentially)\b|\bjust\b(?!\s+(before|after|until|enough|in time))', $RxCI)
    $ReNegation = [regex]::new('\b([Dd]o|[Dd]oes|[Dd]id|[Mm]ust|[Ww]ill|[Ww]ould|[Ss]hould|[Cc]ould) not\b', $RxCS)
    $ReBullet = [regex]::new('^\s*[-*]\s', $RxCS)
    $ReHeading = [regex]::new('^##\s', $RxCS)
    # A tag for the contract check: <name> or </name>, no attributes.
    $ReTag = [regex]::new('</?[A-Za-z_][A-Za-z0-9_-]*>')
}
catch {
    Exit-Usage ('a lint regex does not compile: ' + ($_.Exception.Message -split "`r?`n")[0])
}

$UsageText = 'lint.ps1 <file> <full|ultra> | lint.ps1 --check <src> <dst> <full|ultra>'

# Test-Tier <tier>: only full and ultra are linted (case-sensitive).
function Test-Tier([string]$Tier) {
    if ($Tier -cne 'full' -and $Tier -cne 'ultra') {
        Exit-Usage "tier must be full or ultra, got: $Tier"
    }
}

# Resolve-InputPath <path>: the path against the shell location, not the process one.
function Resolve-InputPath([string]$Path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

# Test-InputFile <path>: the path must name a readable regular file.
function Test-InputFile([string]$Path) {
    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path -LiteralPath $Path)) {
        Exit-Usage "file not found: $Path"
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Exit-Usage "not a readable regular file: $Path"
    }
    try {
        $probe = [System.IO.File]::OpenRead((Resolve-InputPath $Path))
        $probe.Dispose()
    }
    catch {
        Exit-Usage "not a readable regular file: $Path"
    }
}

# Read-InputText <path>: the file as one string, one char per byte (Latin-1), so
# matching is byte-for-byte what lint.sh sees and a CR stays in its line.
function Read-InputText([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-InputPath $Path))
    return [System.Text.Encoding]::Latin1.GetString($bytes)
}

# Get-Findings <fields> <tier>: findings as objects (Line, Text), ordered by line
# and, within a line, by rule number. Lines starting with --- are skipped.
function Get-Findings([string[]]$Fields, [string]$Tier) {
    $found = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $Fields.Length; $i++) {
        $ln = $Fields[$i]
        if ($ln.StartsWith('---', [System.StringComparison]::Ordinal)) { continue }
        $n = $i + 1
        # Rule 1: articles; the finding lists the distinct lowercased hits in order.
        # The allow-list goes first, through the regex's own options (not -replace, whose \b is Unicode).
        $hits = $ReArticle.Matches($ReAtTime.Replace($ln, 'at_time'))
        if ($hits.Count -gt 0) {
            $words = [System.Collections.Generic.List[string]]::new()
            foreach ($h in $hits) {
                $w = $h.Value.ToLowerInvariant()
                if (-not $words.Contains($w)) { $words.Add($w) }
            }
            $found.Add([pscustomobject]@{ Line = $n; Text = 'article(s) ' + ($words -join ',') })
        }
        # Rule 2: filler words.
        if ($ReFiller.IsMatch($ln)) { $found.Add([pscustomobject]@{ Line = $n; Text = 'filler' }) }
        # Rule 3: uncontracted negation (case-sensitive: MUST NOT is not flagged).
        if ($ReNegation.IsMatch($ln)) { $found.Add([pscustomobject]@{ Line = $n; Text = 'uncontracted negation' }) }
        if ($Tier -ceq 'ultra') {
            # Rule 4: list bullet marker at line start.
            if ($ReBullet.IsMatch($ln)) { $found.Add([pscustomobject]@{ Line = $n; Text = 'bullet marker' }) }
            # Rule 5: ## heading at line start.
            if ($ReHeading.IsMatch($ln)) { $found.Add([pscustomobject]@{ Line = $n; Text = '## heading (use Label:)' }) }
        }
    }
    return $found.ToArray()
}

# Remove-TrailingCr <line>: one trailing CR dropped, so CRLF and LF copies compare equal.
function Remove-TrailingCr([string]$Line) {
    if ($Line.Length -gt 0 -and $Line[$Line.Length - 1] -eq [char]13) {
        return $Line.Substring(0, $Line.Length - 1)
    }
    return $Line
}

# Test-FixContract <src> <dst> <tier>: the fix contract. Accept (exit 0, no output) only
# if the field counts are equal, every changed line was flagged in <src>, and <dst>
# holds no more of any tag than <src>. The field count is the number of
# newline-separated fields, as lint.sh counts it (wc -l plus 1, always).
function Test-FixContract([string]$Src, [string]$Dst, [string]$Tier) {
    $srcText = Read-InputText $Src
    $dstText = Read-InputText $Dst
    $srcFields = $srcText.Split([char]10)
    $dstFields = $dstText.Split([char]10)
    $report = [System.Collections.Generic.List[string]]::new()

    if ($srcFields.Length -ne $dstFields.Length) {
        $report.Add("reject: line count $($srcFields.Length) $($dstFields.Length)")
    }

    # A changed line is allowed only where the lint flags the same line of <src>.
    $flagged = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($f in @(Get-Findings $srcFields $Tier)) { [void]$flagged.Add($f.Line) }
    $shorter = [Math]::Min($srcFields.Length, $dstFields.Length)
    for ($i = 0; $i -lt $shorter; $i++) {
        $a = Remove-TrailingCr $srcFields[$i]
        $b = Remove-TrailingCr $dstFields[$i]
        if (-not [string]::Equals($a, $b, [System.StringComparison]::Ordinal) -and -not $flagged.Contains($i + 1)) {
            $report.Add("reject: line $($i + 1)")
        }
    }

    # <dst> may hold no more of any one tag than <src>; report in order of first appearance in <dst>.
    $srcTags = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::Ordinal)
    foreach ($t in $ReTag.Matches($srcText)) {
        $key = $t.Value
        if ($srcTags.ContainsKey($key)) { $srcTags[$key] = $srcTags[$key] + 1 } else { $srcTags[$key] = 1 }
    }
    $dstTags = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::Ordinal)
    $order = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $ReTag.Matches($dstText)) {
        $key = $t.Value
        if ($dstTags.ContainsKey($key)) {
            $dstTags[$key] = $dstTags[$key] + 1
        }
        else {
            $dstTags[$key] = 1
            $order.Add($key)
        }
    }
    foreach ($key in $order) {
        $before = 0
        if ($srcTags.ContainsKey($key)) { $before = $srcTags[$key] }
        if ($dstTags[$key] -gt $before) { $report.Add("reject: tag $key") }
    }

    if ($report.Count -gt 0) {
        Write-Out (($report -join "`n") + "`n")
        Exit-With 1
    }
    Exit-With 0
}

# -----------------------------------------------------------------------
# Main: validate every argument before any output, then run one mode.
# -----------------------------------------------------------------------
if ($RawArgs.Count -ge 1 -and $RawArgs[0] -ceq '--check') {
    if ($RawArgs.Count -ne 4) { Exit-Usage $UsageText }
    Test-Tier $RawArgs[3]
    Test-InputFile $RawArgs[1]
    Test-InputFile $RawArgs[2]
    Test-FixContract $RawArgs[1] $RawArgs[2] $RawArgs[3]
}

if ($RawArgs.Count -ne 2) { Exit-Usage $UsageText }
Test-Tier $RawArgs[1]
Test-InputFile $RawArgs[0]

$fields = (Read-InputText $RawArgs[0]).Split([char]10)
$findings = @(Get-Findings $fields $RawArgs[1])
if ($findings.Count -gt 0) {
    $out = foreach ($f in $findings) { "line $($f.Line): $($f.Text)" }
    Write-Out (($out -join "`n") + "`n")
    Exit-With 1
}
Exit-With 0
