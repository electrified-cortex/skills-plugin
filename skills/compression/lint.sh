#!/usr/bin/env bash
# lint.sh -- deterministic compression lint (detect-only) and fix-contract check
# Usage: lint.sh <file> <full|ultra>
#        lint.sh --check <src> <dst> <full|ultra>
#   <file>, <src>, <dst>  path to a readable regular file (relative or absolute)
#   <full|ultra>          compression tier; lite and none are not linted
# Output (plain text, LF): lint mode prints one finding per line, "line N: <rule>",
#   and nothing when the file is clean. --check prints one "reject: ..." line per
#   violation and nothing when the fix is accepted.
# Exit: 0 clean or accepted, 1 findings or rejected, 2 usage error or a grep that
#   cannot run the rules or a sed that fails (stderr only, nothing on stdout).
# See lint.spec.md for the full contract. Keep in sync with lint.ps1 -- both must
# print the same stdout and exit with the same code for the same inputs.
# Safety: an argument is only ever a quoted file path or a tier word. Nothing is
# evaluated or executed from an argument, and no file is ever modified.
set -eu

# Byte semantics: \b and \s are ASCII-only here. The JavaScript reference differs
# on \s: there it is Unicode and also matches the no-break space, the byte order
# mark and the U+2000 spaces.
export LC_ALL=C

NL='
'

# -----------------------------------------------------------------------
# The five lint rules (PCRE, for grep -P; the rule 1 allow-list is a GNU sed substitution). Keep in exact sync with lint.ps1
# and with lint.spec.md. Rules 1 and 2 are case-insensitive, rule 3 is
# case-sensitive (its regex spells out the capitals), rules 4 and 5 are
# ultra only.
# -----------------------------------------------------------------------
RE_ARTICLE='\b(a|an|the)\b'
RE_FILLER='\b(simply|really|basically|actually|essentially)\b|\bjust\b(?!\s+(before|after|until|enough|in time))'
RE_NEGATION='\b([Dd]o|[Dd]oes|[Dd]id|[Mm]ust|[Ww]ill|[Ww]ould|[Ss]hould|[Cc]ould) not\b'
RE_BULLET='^\s*[-*]\s'
RE_HEADING='^##\s'
# Rule 1 allow-list (GNU sed, case-insensitive): "at a time" becomes the internal
# placeholder at_time ahead of rule 1, so its a is no article hit; never printed.
RE_ATIME='\bat a time\b'
# A tag for the contract check: <name> or </name>, no attributes (ERE).
RE_TAG='</?[A-Za-z_][A-Za-z0-9_-]*>'

# die_usage <message>: usage error, message on stderr, nothing on stdout, exit 2.
die_usage() {
  printf 'usage: %s\n' "$1" >&2
  exit 2
}

# check_tier <tier>: only full and ultra are linted.
check_tier() {
  case "$1" in
    full|ultra) ;;
    *) die_usage "tier must be full or ultra, got: $1" ;;
  esac
}

# check_file <path>: the path must name a readable regular file.
check_file() {
  if [ ! -e "$1" ]; then
    die_usage "file not found: $1"
  fi
  if [ ! -f "$1" ] || [ ! -r "$1" ]; then
    die_usage "not a readable regular file: $1"
  fi
}

# grep_ok <status>: the exit status of one grep. 0 (match) and 1 (no match) are
# results. 2 or more (no -P, a regex that does not compile, a failure while
# running) ends the run as a usage error. Never treat it as "no findings": a
# grep inside a pipeline ahead of awk is otherwise hidden behind awk's exit 0.
grep_ok() {
  if [ "${1:-2}" -ge 2 ]; then
    die_usage "grep failed with exit ${1:-2}; lint.sh needs GNU grep with -P (PCRE) and regexes that compile"
  fi
}

# skip_dashes <file>: the file with every line that starts with --- blanked, so
# line numbers stay put and those lines are never linted.
skip_dashes() {
  sed -e 's/^---.*//' -- "$1"
}

# lint_findings <file> <tier>: prints "line N: <rule>" findings, ordered by line
# and, within a line, by rule number. One finding per rule per line.
lint_findings() {
  local file="$1" tier="$2" tab pst
  tab=$(printf '\t')
  {
    # Rule 1: articles. The finding lists the distinct lowercased hits in order
    # of first appearance (grep -o prints one "line:hit" per match). The sed stage
    # shifts the pipeline's positions: copy PIPESTATUS at once, check sed and grep.
    skip_dashes "$file" | sed -e "s/$RE_ATIME/at_time/Ig" | grep -a -U -n -o -i -P -- "$RE_ARTICLE" | awk -F: '
      {
        n = $1 + 0
        w = tolower($2)
      }
      n != cur {
        if (cur != "") printf "%d\t1\tarticle(s) %s\n", cur, lst
        cur = n; lst = w; split("", seen); seen[w] = 1
        next
      }
      !(w in seen) { seen[w] = 1; lst = lst "," w }
      END { if (cur != "") printf "%d\t1\tarticle(s) %s\n", cur, lst }
    '
    pst=("${PIPESTATUS[@]}")
    grep_ok "${pst[2]}"
    [ "${pst[1]:-1}" -eq 0 ] || die_usage "sed failed with exit ${pst[1]:-1}; lint.sh needs GNU sed with the I flag"
    # Rule 2: filler words.
    skip_dashes "$file" | grep -a -U -n -i -P -- "$RE_FILLER" | awk -F: '{ printf "%d\t2\tfiller\n", $1 }'
    grep_ok "${PIPESTATUS[1]}"
    # Rule 3: uncontracted negation (case-sensitive: MUST NOT is not flagged).
    skip_dashes "$file" | grep -a -U -n -P -- "$RE_NEGATION" | awk -F: '{ printf "%d\t3\tuncontracted negation\n", $1 }'
    grep_ok "${PIPESTATUS[1]}"
    if [ "$tier" = ultra ]; then
      # Rule 4: list bullet marker at line start.
      skip_dashes "$file" | grep -a -U -n -P -- "$RE_BULLET" | awk -F: '{ printf "%d\t4\tbullet marker\n", $1 }'
      grep_ok "${PIPESTATUS[1]}"
      # Rule 5: ## heading at line start.
      skip_dashes "$file" | grep -a -U -n -P -- "$RE_HEADING" | awk -F: '{ printf "%d\t5\t## heading (use Label:)\n", $1 }'
      grep_ok "${PIPESTATUS[1]}"
    fi
  } | sort -t "$tab" -k1,1n -k2,2n | awk -F "$tab" '{ printf "line %d: %s\n", $1, $3 }'
  # A grep or sed that failed ended the group above with exit 2. Fail closed:
  # the caller holds this output in a variable and prints none of it.
  [ "${PIPESTATUS[0]}" -eq 0 ] || exit 2
}

# differing_lines <src> <dst> <fields-src> <fields-dst> <flagged>: one
# "reject: line N" for each line N, up to the shorter field count, whose text in
# <dst> differs from line N of <src> (compared by position, one trailing CR
# ignored) and is not in <flagged> (a space-separated list of line numbers).
# The paths travel in the environment so awk never interprets them.
differing_lines() {
  SRC_PATH="$1" DST_PATH="$2" awk -v s="$3" -v d="$4" -v flagged="$5" '
    function load(path, arr,    line, n) {
      if (path == "-") path = "./-"
      n = 0
      while ((getline line < path) > 0) {
        sub(/\r$/, "", line)
        arr[++n] = line
      }
      close(path)
    }
    BEGIN {
      n = split(flagged, f, " ")
      for (i = 1; i <= n; i++) fl[f[i]] = 1
      load(ENVIRON["SRC_PATH"], a)
      load(ENVIRON["DST_PATH"], b)
      m = (s + 0 < d + 0) ? s + 0 : d + 0
      for (i = 1; i <= m; i++) {
        if (((a[i] "") != (b[i] "")) && !(i in fl)) print "reject: line " i
      }
    }
  '
}

# tags_of <file>: every tag in the file, one per line. Returns grep's own status
# (1 = no tag, not an error); the caller passes it to grep_ok.
tags_of() {
  grep -a -U -o -E -- "$RE_TAG" "$1" 2>/dev/null
}

# added_tags <src> <dst>: one "reject: tag <tag>" for each tag that <dst> holds
# more often than <src>, in order of first appearance in <dst>.
added_tags() {
  {
    tags_of "$1" | sed -e 's/^/S /'
    grep_ok "${PIPESTATUS[0]}"
    tags_of "$2" | sed -e 's/^/D /'
    grep_ok "${PIPESTATUS[0]}"
  } | awk '
    $1 == "S" { sc[$2]++; next }
    {
      if (!($2 in dc)) order[++no] = $2
      dc[$2]++
    }
    END {
      for (i = 1; i <= no; i++) {
        t = order[i]
        if (dc[t] > sc[t] + 0) print "reject: tag " t
      }
    }
  '
  # A grep that failed ended the group above with exit 2 (grep_ok): fail closed.
  [ "${PIPESTATUS[0]}" -eq 0 ] || exit 2
}

# probe_grep: the startup probe, run after the argument checks and before any
# output. It runs every rule's grep (all five at ultra), the allow-list sed and the tag grep once on
# an empty file, constants only, so a grep without -P, or a regex that does not
# compile, ends here as a usage error (exit 2) and never as a clean result.
probe_grep() {
  lint_findings /dev/null ultra > /dev/null
  added_tags /dev/null /dev/null > /dev/null
}

# run_check <src> <dst> <tier>: the fix contract. Accept (exit 0, no output) only
# if the field counts are equal, every changed line was flagged in <src>, and
# <dst> holds no more of any tag than <src>. The field count is the number of
# newline-separated fields: wc -l plus 1, always.
run_check() {
  local src="$1" dst="$2" tier="$3" ns nd findings flagged lines tags report=""
  ns=$(( $(wc -l < "$src") + 1 ))
  nd=$(( $(wc -l < "$dst") + 1 ))
  if [ "$ns" -ne "$nd" ]; then
    report="reject: line count $ns $nd"
  fi
  findings=$(lint_findings "$src" "$tier") || exit 2
  flagged=$(printf '%s\n' "$findings" | sed -n -e 's/^line \([0-9][0-9]*\):.*/\1/p' | tr '\n' ' ')
  lines=$(differing_lines "$src" "$dst" "$ns" "$nd" "$flagged")
  tags=$(added_tags "$src" "$dst") || exit 2
  if [ -n "$lines" ]; then
    report="${report:+$report$NL}$lines"
  fi
  if [ -n "$tags" ]; then
    report="${report:+$report$NL}$tags"
  fi
  if [ -n "$report" ]; then
    printf '%s\n' "$report"
    exit 1
  fi
  exit 0
}

# -----------------------------------------------------------------------
# Main: validate every argument before any output, then run one mode.
# -----------------------------------------------------------------------
USAGE_TEXT='lint.sh <file> <full|ultra> | lint.sh --check <src> <dst> <full|ultra>'

if [ "$#" -ge 1 ] && [ "$1" = "--check" ]; then
  if [ "$#" -ne 4 ]; then
    die_usage "$USAGE_TEXT"
  fi
  check_tier "$4"
  check_file "$2"
  check_file "$3"
  probe_grep
  run_check "$2" "$3" "$4"
fi

if [ "$#" -ne 2 ]; then
  die_usage "$USAGE_TEXT"
fi
check_tier "$2"
check_file "$1"
probe_grep

findings=$(lint_findings "$1" "$2") || exit 2
if [ -n "$findings" ]; then
  printf '%s\n' "$findings"
  exit 1
fi
exit 0
