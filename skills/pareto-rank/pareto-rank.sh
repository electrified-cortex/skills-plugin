#!/usr/bin/env bash
# pareto-rank — Pure CSV-in / CSV-out Pareto ranking tool.
# Higher dimension value = better. Caller negates columns to invert.
#
# Usage:
#   pareto-rank.sh rank <csv>          — emit all rows + rank col, Pareto order
#   pareto-rank.sh next <csv>          — alias for rank
#   pareto-rank.sh top <dim> <csv>     — single row with max value in <dim>

set -euo pipefail

# Globals populated by _read_csv
declare -a RAW_LINES=() HEADER_COLS=() IDS=() DIMS_FLAT=()
declare -i N=0 DATA_START=0 NUM_DIMS=0

usage() {
  echo "Usage:" >&2
  echo "  $0 rank <csv>" >&2
  echo "  $0 next <csv>" >&2
  echo "  $0 top <dim> <csv>" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# _trim <string>  — echo trimmed string
# ---------------------------------------------------------------------------
_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  echo "$s"
}

# ---------------------------------------------------------------------------
# _read_csv <file>
# Populates globals: HEADER_COLS, NUM_DIMS, IDS, DIMS_FLAT, N, DATA_START
# ---------------------------------------------------------------------------
_read_csv() {
  local csv_file="$1"
  if [[ ! -f "$csv_file" ]]; then
    echo "Error: file not found: $csv_file" >&2; exit 1
  fi

  RAW_LINES=(); IDS=(); DIMS_FLAT=(); HEADER_COLS=()
  mapfile -t RAW_LINES < <(tr -d '\r' < "$csv_file")

  # Drop empty trailing lines
  local last=$(( ${#RAW_LINES[@]} - 1 ))
  while [[ $last -ge 0 && -z "${RAW_LINES[$last]}" ]]; do
    unset 'RAW_LINES[$last]'
    last=$(( last - 1 ))
  done

  if [[ ${#RAW_LINES[@]} -eq 0 ]]; then
    N=0; return 0
  fi

  local -a _first=()
  IFS=',' read -ra _first <<< "${RAW_LINES[0]}"
  if [[ ${#_first[@]} -lt 2 ]]; then
    echo "Error: fewer than 2 columns in row 1 — no dimensions found." >&2; exit 1
  fi

  # Header detection: col 2 of row 1 non-numeric => header row
  local col2
  col2=$(_trim "${_first[1]}")
  local has_header=0
  if [[ ! "$col2" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    has_header=1
  fi

  DATA_START=0
  if [[ $has_header -eq 1 ]]; then
    local -a _raw_hdr=()
    IFS=',' read -ra _raw_hdr <<< "${RAW_LINES[0]}"
    HEADER_COLS=()
    local h
    for h in "${_raw_hdr[@]}"; do
      HEADER_COLS+=("$(_trim "$h")")
    done
    DATA_START=1
  else
    local ncols=${#_first[@]}
    HEADER_COLS=("id")
    local c
    for (( c=2; c<=ncols; c++ )); do HEADER_COLS+=("d$((c-1))"); done
    DATA_START=0
  fi

  local num_cols=${#HEADER_COLS[@]}
  NUM_DIMS=$(( num_cols - 1 ))
  if [[ $NUM_DIMS -lt 1 ]]; then
    echo "Error: fewer than 2 columns — no dimensions found." >&2; exit 1
  fi

  N=0
  local i
  for (( i=DATA_START; i<${#RAW_LINES[@]}; i++ )); do
    local line="${RAW_LINES[$i]}"
    if [[ -z "$line" ]]; then continue; fi

    local -a fields=()
    IFS=',' read -ra fields <<< "$line"

    if [[ ${#fields[@]} -lt $num_cols ]]; then
      echo "Error: row $((i+1)) has ${#fields[@]} columns, expected $num_cols." >&2; exit 1
    fi

    IDS+=("$(_trim "${fields[0]}")")

    local d
    for (( d=0; d<NUM_DIMS; d++ )); do
      local val
      val=$(_trim "${fields[$((d+1))]}")
      if [[ ! "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: non-numeric value '$val' at row $((i+1)), column ${HEADER_COLS[$((d+1))]}." >&2; exit 1
      fi
      DIMS_FLAT+=("$val")
    done
    N=$(( N + 1 ))
  done
}

# ---------------------------------------------------------------------------
# _dominates <a_idx> <b_idx>
# Returns 0 (true) if item a dominates item b (a >= b all dims, a > b one dim)
# ---------------------------------------------------------------------------
_dominates() {
  local -i a=$1 b=$2
  local -i all_ge=1 any_gt=0
  local d
  for (( d=0; d<NUM_DIMS; d++ )); do
    local va="${DIMS_FLAT[$((a * NUM_DIMS + d))]}"
    local vb="${DIMS_FLAT[$((b * NUM_DIMS + d))]}"
    local result
    result=$(awk -v va="$va" -v vb="$vb" 'BEGIN {
      if (va >= vb && va > vb) print "gt"
      else if (va >= vb) print "ge"
      else print "lt"
    }')
    if [[ "$result" == "lt" ]]; then all_ge=0; break; fi
    if [[ "$result" == "gt" ]]; then any_gt=1; fi
  done
  if [[ $all_ge -eq 1 && $any_gt -eq 1 ]]; then return 0; fi
  return 1
}

# ---------------------------------------------------------------------------
# cmd_rank <csv>
# ---------------------------------------------------------------------------
cmd_rank() {
  _read_csv "$1"
  if [[ $N -eq 0 ]]; then return 0; fi

  local -a ranks=()
  local i
  for (( i=0; i<N; i++ )); do ranks+=(0); done

  local current_rank=1
  local remaining=$N

  while [[ $remaining -gt 0 ]]; do
    local -a front=()
    for (( i=0; i<N; i++ )); do
      if [[ ${ranks[$i]} -ne 0 ]]; then continue; fi
      local dominated=0
      local j
      for (( j=0; j<N; j++ )); do
        if [[ $i -eq $j ]]; then continue; fi
        if [[ ${ranks[$j]} -ne 0 ]]; then continue; fi
        if _dominates "$j" "$i"; then dominated=1; break; fi
      done
      if [[ $dominated -eq 0 ]]; then front+=("$i"); fi
    done

    local idx
    for idx in "${front[@]}"; do ranks[$idx]=$current_rank; done
    remaining=$(( remaining - ${#front[@]} ))
    current_rank=$(( current_rank + 1 ))
  done

  # Compute dimension sums for tie-breaking
  local -a dim_sums=()
  for (( i=0; i<N; i++ )); do
    local sum=0
    local d
    for (( d=0; d<NUM_DIMS; d++ )); do
      sum=$(awk -v s="$sum" -v v="${DIMS_FLAT[$((i * NUM_DIMS + d))]}" 'BEGIN { printf "%.10g", s+v }')
    done
    dim_sums+=("$sum")
  done

  # Build sortable table: rank<TAB>neg_sum<TAB>id<TAB>orig_index
  local -a sort_lines=()
  for (( i=0; i<N; i++ )); do
    local neg_sum
    neg_sum=$(awk -v s="${dim_sums[$i]}" 'BEGIN { printf "%.10g", -s }')
    sort_lines+=("$(printf '%d\t%s\t%s\t%d' "${ranks[$i]}" "$neg_sum" "${IDS[$i]}" "$i")")
  done

  local sorted_indices
  sorted_indices=$(printf '%s\n' "${sort_lines[@]}" | sort -t$'\t' -k1,1n -k2,2n -k3,3 | awk -F'\t' '{print $4}')

  # Emit header
  local header
  header=$(IFS=','; echo "${HEADER_COLS[*]},rank")
  echo "$header"

  # Emit rows
  while IFS= read -r idx; do
    local row="${IDS[$idx]}"
    local d
    for (( d=0; d<NUM_DIMS; d++ )); do
      row+=",$( printf '%g' "${DIMS_FLAT[$((idx * NUM_DIMS + d))]}" )"
    done
    row+=",${ranks[$idx]}"
    echo "$row"
  done <<< "$sorted_indices"
}

# ---------------------------------------------------------------------------
# cmd_top <dim> <csv>
# ---------------------------------------------------------------------------
cmd_top() {
  local dim_arg="$1"
  _read_csv "$2"
  if [[ $N -eq 0 ]]; then return 0; fi

  # Resolve dim to 0-based index into dimensions (cols 2..M)
  local dim_idx=-1
  if [[ "$dim_arg" =~ ^[0-9]+$ ]]; then
    if (( dim_arg >= 1 && dim_arg <= NUM_DIMS )); then
      dim_idx=$(( dim_arg - 1 ))
    else
      echo "Error: dimension index $dim_arg out of range (1..$NUM_DIMS)." >&2; exit 1
    fi
  else
    local c
    for (( c=1; c<${#HEADER_COLS[@]}; c++ )); do
      if [[ "${HEADER_COLS[$c]}" == "$dim_arg" ]]; then
        dim_idx=$(( c - 1 )); break
      fi
    done
    if [[ $dim_idx -eq -1 ]]; then
      echo "Error: unknown dimension '$dim_arg'. Valid dimensions: ${HEADER_COLS[*]:1}" >&2; exit 1
    fi
  fi

  # Find row with max value in dim_idx
  local best_val="" best_idx=0
  local i
  for (( i=0; i<N; i++ )); do
    local val="${DIMS_FLAT[$((i * NUM_DIMS + dim_idx))]}"
    if [[ -z "$best_val" ]]; then
      best_val="$val"; best_idx=$i
    else
      local cmp
      cmp=$(awk -v a="$val" -v b="$best_val" 'BEGIN { if (a > b) print "gt"; else print "le" }')
      if [[ "$cmp" == "gt" ]]; then best_val="$val"; best_idx=$i; fi
    fi
  done

  # Emit header + best row (no rank column for top)
  local header
  header=$(IFS=','; echo "${HEADER_COLS[*]}")
  echo "$header"

  local row="${IDS[$best_idx]}"
  local d
  for (( d=0; d<NUM_DIMS; d++ )); do
    row+=",$( printf '%g' "${DIMS_FLAT[$((best_idx * NUM_DIMS + d))]}" )"
  done
  echo "$row"
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then usage; fi

CMD="$1"; shift

case "$CMD" in
  rank|next)
    if [[ $# -lt 1 ]]; then echo "Error: missing <csv>." >&2; usage; fi
    cmd_rank "$1"
    ;;
  top)
    if [[ $# -lt 2 ]]; then echo "Error: top requires <dim> <csv>." >&2; usage; fi
    cmd_top "$1" "$2"
    ;;
  *)
    echo "Error: unknown command '$CMD'." >&2; usage
    ;;
esac
