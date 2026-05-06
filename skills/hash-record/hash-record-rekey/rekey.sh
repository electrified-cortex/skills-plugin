#!/usr/bin/env bash
# rekey.sh — hash-record re-key after file content change
# Usage (per-file): rekey <file_path> <op_kind> <record_filename> [source_hash]
# Usage (folder):   rekey <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests <bool>]
# Outputs one of:
#   REKEYED: <new_abs_path>
#   CURRENT: <abs_path>
#   NOT_FOUND: no record for <op_kind>/<record_filename>   (per-file)
#   NOT_FOUND: no record for <file-rel-path>               (folder)
#   AMBIGUOUS: <n> records found -- manual resolution required
#   MANIFEST_UPDATED: <manifest-path>:<entry-id>
#   SUMMARY: rekeyed=<n> current=<n> manifest_updated=<n> not_found=<n> errors=<n>
#   ERROR: <reason>
set -euo pipefail

# ---------------------------------------------------------------------------
# Help text
# ---------------------------------------------------------------------------
_print_help() {
  printf 'Usage (per-file): rekey <file_path> <op_kind> <record_filename> [source_hash]\n'
  printf 'Usage (folder):   rekey <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests <bool>]\n'
  printf '\n'
  printf 'Re-key hash-record entries after source file content changes.\n'
  printf '\n'
  printf 'Per-file arguments:\n'
  printf '  file_path        Absolute path to the changed file (new content, not yet committed).\n'
  printf '  op_kind          Operation kind, e.g. "markdown-hygiene" or "skill-auditing/v2". May contain /.\n'
  printf '  record_filename  Leaf filename, e.g. "claude-haiku.md". No path separators or ..\n'
  printf '  source_hash      (Optional) The known old content hash. Skips full-tree search when provided.\n'
  printf '\n'
  printf 'Folder-mode flags (first arg is an existing directory):\n'
  printf '  --include <glob>    Restrict scope to matching files (repeatable; default: all).\n'
  printf '  --exclude <glob>    Skip matching files (repeatable; default: none).\n'
  printf '  --dry-run           Report changes without performing git mv or writes.\n'
  printf '  --manifests <bool>  Include manifest entries (default: true).\n'
  printf '\n'
  printf 'Per-file output (stdout, one line):\n'
  printf '  REKEYED: <abs-path>   Record moved to new hash path.\n'
  printf '  CURRENT: <abs-path>   Old hash == new hash. No move needed.\n'
  printf '  NOT_FOUND: ...        No record exists for this op_kind/record_filename.\n'
  printf '  AMBIGUOUS: <n> ...    Multiple records found -- manual resolution required.\n'
  printf '  ERROR: <reason>       Argument or runtime error.\n'
  printf '\n'
  printf 'Folder-mode output (stdout, one line per record, then summary):\n'
  printf '  REKEYED: <abs-path>\n'
  printf '  CURRENT: <abs-path>\n'
  printf '  NOT_FOUND: no record for <file-rel-path>\n'
  printf '  MANIFEST_UPDATED: <manifest-path>:<entry-id>\n'
  printf '  ERROR: <reason>\n'
  printf '  SUMMARY: rekeyed=<n> current=<n> manifest_updated=<n> not_found=<n> errors=<n>\n'
  printf '\n'
  printf 'Exit codes:\n'
  printf '  0   Success (or --dry-run with no errors).\n'
  printf '  1   Per-record error (attempts all before exiting).\n'
  printf '  2   Invocation error (bad path, bad flags).\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  _print_help
  exit 0
fi

# ---------------------------------------------------------------------------
# Detect mode: folder vs per-file
# ---------------------------------------------------------------------------
FIRST_ARG="${1:-}"

if [ -z "$FIRST_ARG" ]; then
  printf 'ERROR: missing arguments -- expected <file_path> <op_kind> <record_filename> or <folder_path>\n'
  exit 2
fi

if [ -d "$FIRST_ARG" ]; then
  # =========================================================================
  # FOLDER MODE
  # =========================================================================
  FOLDER_PATH="$FIRST_ARG"
  shift

  INCLUDES=()
  EXCLUDES=()
  DRY_RUN=false
  DO_MANIFESTS=true

  # Parse flags
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --include)
        [ "$#" -lt 2 ] && { printf 'ERROR: --include requires a value\n'; exit 2; }
        INCLUDES+=("$2"); shift 2 ;;
      --exclude)
        [ "$#" -lt 2 ] && { printf 'ERROR: --exclude requires a value\n'; exit 2; }
        EXCLUDES+=("$2"); shift 2 ;;
      --dry-run)
        DRY_RUN=true; shift ;;
      --manifests)
        [ "$#" -lt 2 ] && { printf 'ERROR: --manifests requires a value (true|false)\n'; exit 2; }
        case "$2" in
          true|1|yes)  DO_MANIFESTS=true  ;;
          false|0|no)  DO_MANIFESTS=false ;;
          *) printf 'ERROR: --manifests value must be true or false, got: %s\n' "$2"; exit 2 ;;
        esac
        shift 2 ;;
      --help|-h)
        _print_help; exit 0 ;;
      *)
        printf 'ERROR: unknown flag: %s\n' "$1"; exit 2 ;;
    esac
  done

  # Resolve repo root from folder_path
  REPO_ROOT=$(git -C "$FOLDER_PATH" rev-parse --show-toplevel 2>/dev/null) || true
  if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$FOLDER_PATH"
    printf 'WARN: not in a git repo; falling back to folder_path as repo_root: %s\n' "$REPO_ROOT" >&2
  fi
  REPO_ROOT_FWD=$(printf '%s' "$REPO_ROOT" | tr '\\' '/')

  # Normalize folder_path to forward slashes, no trailing slash
  FOLDER_PATH_FWD=$(printf '%s' "$FOLDER_PATH" | tr '\\' '/')
  FOLDER_PATH_FWD="${FOLDER_PATH_FWD%/}"

  HASH_RECORD_ROOT="$REPO_ROOT_FWD/.hash-record"

  # ---------------------------------------------------------------------------
  # Helper: extract file_path / file_paths from YAML frontmatter
  # Prints one repo-relative path per line.
  # ---------------------------------------------------------------------------
  _get_frontmatter_paths() {
    local rec_file="$1"
    local past_open=0
    local collecting_list=0
    while IFS= read -r line; do
      # Strip CR for Windows line endings
      line="${line%$'\r'}"
      line="${line#$'\xef\xbb\xbf'}"         # strip UTF-8 BOM if present
      if [ "$past_open" -eq 0 ]; then
        [ "$line" = "---" ] && past_open=1
        continue
      fi
      # End of frontmatter
      [ "$line" = "---" ] && break
      # file_path: single value
      if [[ "$line" =~ ^file_path:[[:space:]]+(.+)$ ]]; then
        collecting_list=0
        printf '%s\n' "${BASH_REMATCH[1]}"
      # file_paths: list start
      elif [[ "$line" =~ ^file_paths:[[:space:]]*$ ]]; then
        collecting_list=1
      # list item under file_paths
      elif [ "$collecting_list" -eq 1 ] && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
      else
        # Any other top-level key resets list mode
        if [[ "$line" =~ ^[a-z_]+: ]]; then
          collecting_list=0
        fi
      fi
    done < "$rec_file"
  }

  # ---------------------------------------------------------------------------
  # Helper: compute manifest hash for a multi-file record
  # git-blob hash (SHA-1, 40-char hex) of the sorted "<blob_hash> <path>\n"
  # manifest string. Matches `hash-record-manifest/manifest.ps1` semantics
  # exactly: write manifest text to a temp file, run `git hash-object` on
  # it. The result tools also use `git hash-object` to compute lookups, so
  # using SHA-1-via-git keeps rekey output and result-tool input in sync.
  # Prints 40-char hex hash to stdout. Returns 1 on error.
  # ---------------------------------------------------------------------------
  _compute_manifest_hash() {
    local rec_path="$1"
    local repo_root="$2"

    local -a paths=()
    while IFS= read -r fpath; do
      fpath="${fpath%$'\r'}"
      fpath="${fpath## }"; fpath="${fpath%% }"
      [ -n "$fpath" ] && paths+=("$fpath")
    done < <(_get_frontmatter_paths "$rec_path" 2>/dev/null)

    if [ "${#paths[@]}" -eq 0 ]; then
      printf 'ERROR: no file_paths found in: %s\n' "$rec_path" >&2
      return 1
    fi

    # Build pairs first ("<path> <blob_hash>"), then sort the FULL pair
    # strings — exact mirror of hash-record-manifest/manifest.ps1
    # (lines 99 + 106). Sorting only by path can produce a different order
    # in edge cases and yields an incompatible hash.
    local -a pairs=() fpath blob_hash
    for fpath in "${paths[@]}"; do
      blob_hash=$(git hash-object "$repo_root/$fpath" 2>/dev/null) || {
        printf 'ERROR: git hash-object failed for manifest member: %s\n' "$fpath" >&2
        return 1
      }
      [ -z "$blob_hash" ] && {
        printf 'ERROR: empty hash for manifest member: %s\n' "$fpath" >&2
        return 1
      }
      # Format MUST match manifest.ps1: `<path> <blob_hash>` (path first).
      pairs+=("${fpath} ${blob_hash}")
    done

    # Same sort as manifest.ps1: ordinal, byte-order. LC_ALL=C ensures
    # bash `sort` matches PowerShell `Sort-Object -CaseSensitive -Culture ''`.
    local -a sorted_pairs
    IFS=$'\n' read -r -d '' -a sorted_pairs \
      < <(printf '%s\n' "${pairs[@]}" | LC_ALL=C sort; printf '\0') || true

    local manifest_str="" pair
    for pair in "${sorted_pairs[@]}"; do
      manifest_str="${manifest_str}${pair}"$'\n'
    done

    # Write manifest to a temp file and run `git hash-object`. Direct
    # sha256sum would produce a different, incompatible 64-char hex; the
    # result tools cannot find that path. Use git's content-blob hash so
    # rekey paths and result-tool lookups agree.
    local tmpf
    tmpf=$(mktemp) || {
      printf 'ERROR: mktemp failed\n' >&2
      return 1
    }
    printf '%s' "$manifest_str" > "$tmpf"
    local manifest_hash
    manifest_hash=$(git hash-object "$tmpf" 2>/dev/null) || {
      rm -f "$tmpf"
      printf 'ERROR: git hash-object failed for manifest tmp file\n' >&2
      return 1
    }
    rm -f "$tmpf"
    [ -z "$manifest_hash" ] && {
      printf 'ERROR: git hash-object returned empty manifest hash\n' >&2
      return 1
    }
    printf '%s\n' "$manifest_hash"
  }

  # ---------------------------------------------------------------------------
  # Helper: glob match (bash case-based)
  # ---------------------------------------------------------------------------
  _matches_any_glob() {
    local rel_path="$1"
    shift
    local glob
    for glob in "$@"; do
      case "$rel_path" in
        $glob) return 0 ;;
      esac
    done
    return 1
  }

  # ---------------------------------------------------------------------------
  # Load all records into memory as tab-separated entries
  # Format: rec_path_fwd <TAB> rec_hash <TAB> op_kind <TAB> rec_filename
  # ---------------------------------------------------------------------------
  declare -a ALL_RECORDS=()
  if [ -d "$HASH_RECORD_ROOT" ]; then
    while IFS= read -r -d '' rec_path; do
      rec_path_fwd=$(printf '%s' "$rec_path" | tr '\\' '/')
      after_root="${rec_path_fwd#${HASH_RECORD_ROOT}/}"
      # after_root = <shard>/<hash>/<op_kind...>/<record_filename>
      after_shard="${after_root#*/}"           # strip shard
      rec_hash="${after_shard%%/*}"
      after_hash="${after_shard#*/}"           # <op_kind...>/<record_filename>
      rec_filename="${after_hash##*/}"
      op_kind_part="${after_hash%/*}"
      ALL_RECORDS+=("${rec_path_fwd}	${rec_hash}	${op_kind_part}	${rec_filename}")
    done < <(find "$HASH_RECORD_ROOT" -type f -print0 2>/dev/null)
  fi

  # Counters
  cnt_rekeyed=0
  cnt_current=0
  cnt_manifest_updated=0
  cnt_not_found=0
  cnt_errors=0
  had_error=false

  # Deferred multi-file records (processed after per-file loop)
  declare -A DEFERRED_MANIFESTS=()

  # ---------------------------------------------------------------------------
  # Iterate over files in folder_path
  # ---------------------------------------------------------------------------
  while IFS= read -r file_abs; do
    file_abs_fwd=$(printf '%s' "$file_abs" | tr '\\' '/')

    # Compute repo-relative path
    if [[ "$file_abs_fwd" == "$REPO_ROOT_FWD/"* ]]; then
      file_rel="${file_abs_fwd#${REPO_ROOT_FWD}/}"
    else
      file_rel="$file_abs_fwd"
    fi

    # Compute folder-relative path for include/exclude matching
    if [[ "$file_abs_fwd" == "$FOLDER_PATH_FWD/"* ]]; then
      file_folder_rel="${file_abs_fwd#${FOLDER_PATH_FWD}/}"
    else
      file_folder_rel="$file_rel"
    fi

    # Apply include filter (if any specified)
    if [ "${#INCLUDES[@]}" -gt 0 ]; then
      if ! _matches_any_glob "$file_folder_rel" "${INCLUDES[@]}"; then
        continue
      fi
    fi

    # Apply exclude filter
    if [ "${#EXCLUDES[@]}" -gt 0 ]; then
      if _matches_any_glob "$file_folder_rel" "${EXCLUDES[@]}"; then
        continue
      fi
    fi

    # Compute current blob hash
    current_hash=$(git hash-object "$file_abs" 2>/dev/null) || {
      printf 'ERROR: git hash-object failed for: %s\n' "$file_rel"
      cnt_errors=$((cnt_errors + 1))
      had_error=true
      continue
    }
    if [ -z "$current_hash" ]; then
      printf 'ERROR: git hash-object returned empty hash for: %s\n' "$file_rel"
      cnt_errors=$((cnt_errors + 1))
      had_error=true
      continue
    fi
    current_shard="${current_hash:0:2}"

    # Find all records referencing this file (by file_rel)
    file_records_found=0

    for rec_entry in "${ALL_RECORDS[@]}"; do
      IFS='	' read -r rec_path rec_hash rec_op_kind rec_filename <<< "$rec_entry"

      # Check if this record's frontmatter references file_rel
      references_file=false
      while IFS= read -r fpath; do
        fpath="${fpath%$'\r'}"
        fpath="${fpath## }"
        fpath="${fpath%% }"
        if [ "$fpath" = "$file_rel" ]; then
          references_file=true
          break
        fi
      done < <(_get_frontmatter_paths "$rec_path" 2>/dev/null)

      $references_file || continue

      # This record references our file
      file_records_found=$((file_records_found + 1))

      # Detect single-file vs multi-file record
      _rec_all_paths=()
      while IFS= read -r _fp; do
        _fp="${_fp%$'\r'}"; _fp="${_fp## }"; _fp="${_fp%% }"
        [ -n "$_fp" ] && _rec_all_paths+=("$_fp")
      done < <(_get_frontmatter_paths "$rec_path" 2>/dev/null)
      _path_count="${#_rec_all_paths[@]}"

      if [ "$_path_count" -le 1 ]; then
        # Single-file record: rekey based on this file's current blob hash
        if [ "$rec_hash" = "$current_hash" ]; then
          printf 'CURRENT: %s\n' "$rec_path"
          cnt_current=$((cnt_current + 1))
        else
          new_record_dir="$HASH_RECORD_ROOT/$current_shard/$current_hash/$rec_op_kind"
          new_record_path="$new_record_dir/$rec_filename"

          if $DRY_RUN; then
            printf 'REKEYED: %s\n' "$new_record_path"
            cnt_rekeyed=$((cnt_rekeyed + 1))
          else
            _rec_error=false

            if ! mkdir -p "$new_record_dir" 2>/dev/null; then
              printf 'ERROR: mkdir failed for: %s\n' "$new_record_dir"
              cnt_errors=$((cnt_errors + 1))
              had_error=true
              _rec_error=true
            fi

            if ! $_rec_error; then
              old_rel="${rec_path#${REPO_ROOT_FWD}/}"
              new_rel="${new_record_path#${REPO_ROOT_FWD}/}"

              if ! git -C "$REPO_ROOT" mv "$old_rel" "$new_rel" 2>/dev/null; then
                printf 'ERROR: git mv failed: %s -> %s\n' "$old_rel" "$new_rel"
                cnt_errors=$((cnt_errors + 1))
                had_error=true
                _rec_error=true
              fi
            fi

            if ! $_rec_error; then
              printf 'REKEYED: %s\n' "$new_record_path"
              cnt_rekeyed=$((cnt_rekeyed + 1))
              ALL_RECORDS=("${ALL_RECORDS[@]/$rec_entry/${new_record_path}	${current_hash}	${rec_op_kind}	${rec_filename}}")
            fi
          fi
        fi
      else
        # Multi-file record: defer to manifest-hash processing after per-file loop
        DEFERRED_MANIFESTS["$rec_path"]="${rec_hash}	${rec_op_kind}	${rec_filename}"
      fi
    done

    if [ "$file_records_found" -eq 0 ]; then
      printf 'NOT_FOUND: no record for %s\n' "$file_rel"
      cnt_not_found=$((cnt_not_found + 1))
    fi

  done < <(find "$FOLDER_PATH" -type f -not -path '*/.git/*' 2>/dev/null | LC_ALL=C sort)

  # ---------------------------------------------------------------------------
  # Process deferred multi-file (manifest) records
  # ---------------------------------------------------------------------------
  if $DO_MANIFESTS && [ "${#DEFERRED_MANIFESTS[@]}" -gt 0 ]; then
    for rec_path in "${!DEFERRED_MANIFESTS[@]}"; do
      IFS='	' read -r rec_hash rec_op_kind rec_filename <<< "${DEFERRED_MANIFESTS[$rec_path]}"

      manifest_hash=$(_compute_manifest_hash "$rec_path" "$REPO_ROOT_FWD") || {
        printf 'ERROR: manifest hash computation failed for: %s\n' "$rec_path"
        cnt_errors=$((cnt_errors + 1))
        had_error=true
        continue
      }
      manifest_shard="${manifest_hash:0:2}"

      if [ "$rec_hash" = "$manifest_hash" ]; then
        printf 'CURRENT: %s\n' "$rec_path"
        cnt_current=$((cnt_current + 1))
      else
        new_record_dir="$HASH_RECORD_ROOT/$manifest_shard/$manifest_hash/$rec_op_kind"
        new_record_path="$new_record_dir/$rec_filename"

        if $DRY_RUN; then
          printf 'REKEYED: %s\n' "$new_record_path"
          cnt_rekeyed=$((cnt_rekeyed + 1))
        else
          _rec_error=false

          if ! mkdir -p "$new_record_dir" 2>/dev/null; then
            printf 'ERROR: mkdir failed for: %s\n' "$new_record_dir"
            cnt_errors=$((cnt_errors + 1))
            had_error=true
            _rec_error=true
          fi

          if ! $_rec_error; then
            old_rel="${rec_path#${REPO_ROOT_FWD}/}"
            new_rel="${new_record_path#${REPO_ROOT_FWD}/}"

            if ! git -C "$REPO_ROOT" mv "$old_rel" "$new_rel" 2>/dev/null; then
              printf 'ERROR: git mv failed: %s -> %s\n' "$old_rel" "$new_rel"
              cnt_errors=$((cnt_errors + 1))
              had_error=true
              _rec_error=true
            fi
          fi

          if ! $_rec_error; then
            printf 'REKEYED: %s\n' "$new_record_path"
            cnt_rekeyed=$((cnt_rekeyed + 1))
          fi
        fi
      fi
    done
  fi

  printf 'SUMMARY: rekeyed=%d current=%d manifest_updated=%d not_found=%d errors=%d\n' \
    "$cnt_rekeyed" "$cnt_current" "$cnt_manifest_updated" "$cnt_not_found" "$cnt_errors"

  if $had_error; then
    exit 1
  fi
  exit 0

else
  # =========================================================================
  # PER-FILE MODE (original, unchanged)
  # =========================================================================

  if [ "$#" -lt 3 ]; then
    printf 'ERROR: missing arguments -- expected <file_path> <op_kind> <record_filename>\n'
    exit 2
  fi

  FILE_PATH="$1"
  OP_KIND="$2"
  RECORD_FILENAME="$3"
  SOURCE_HASH="${4:-}"

  if [ -n "$SOURCE_HASH" ]; then
    if ! printf '%s' "$SOURCE_HASH" | grep -qE '^[0-9a-f]{40}$'; then
      echo "ERROR: invalid source_hash: $SOURCE_HASH"
      exit 1
    fi
  fi

  case "$OP_KIND" in
    *..* | *\\*)
      printf 'ERROR: invalid op_kind: %s\n' "$OP_KIND"
      exit 1
      ;;
  esac

  case "$RECORD_FILENAME" in
    *..* | */* | *\\*)
      printf 'ERROR: invalid record_filename: %s\n' "$RECORD_FILENAME"
      exit 1
      ;;
  esac

  TARGET_DIR=$(dirname "$FILE_PATH")
  REPO_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null) || true
  if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$TARGET_DIR"
    printf 'WARN: not in a git repo; falling back to file parent dir: %s\n' "$REPO_ROOT" >&2
  fi

  NEW_HASH=$(git hash-object "$FILE_PATH" 2>/dev/null) || {
    printf 'ERROR: git hash-object failed for: %s\n' "$FILE_PATH"
    exit 1
  }
  [ -z "$NEW_HASH" ] && { printf 'ERROR: git hash-object returned empty hash\n'; exit 1; }
  NEW_SHARD="${NEW_HASH:0:2}"

  HASH_RECORD_ROOT="$REPO_ROOT/.hash-record"

  if [ ! -d "$HASH_RECORD_ROOT" ]; then
    printf 'NOT_FOUND: no record for %s/%s\n' "$OP_KIND" "$RECORD_FILENAME"
    exit 0
  fi

  if [ -n "$SOURCE_HASH" ]; then
    OLD_RECORD_PATH="$HASH_RECORD_ROOT/${SOURCE_HASH:0:2}/$SOURCE_HASH/$OP_KIND/$RECORD_FILENAME"
    if [ ! -f "$OLD_RECORD_PATH" ]; then
      printf 'NOT_FOUND: no record for %s/%s at %s\n' "$OP_KIND" "$RECORD_FILENAME" "$SOURCE_HASH"
      exit 0
    fi
    OLD_HASH="$SOURCE_HASH"
  else
    FOUND=()
    while IFS= read -r -d '' candidate; do
      FOUND+=("$candidate")
    done < <(find "$HASH_RECORD_ROOT" -type f -path "*/${OP_KIND}/${RECORD_FILENAME}" -print0 2>/dev/null)

    COUNT="${#FOUND[@]}"

    if [ "$COUNT" -eq 0 ]; then
      printf 'NOT_FOUND: no record for %s/%s\n' "$OP_KIND" "$RECORD_FILENAME"
      exit 0
    fi

    if [ "$COUNT" -gt 1 ]; then
      printf 'AMBIGUOUS: %d records found -- manual resolution required\n' "$COUNT"
      exit 1
    fi

    OLD_RECORD_PATH="${FOUND[0]}"
    AFTER_PREFIX="${OLD_RECORD_PATH#${HASH_RECORD_ROOT}/}"
    OLD_SHARD="${AFTER_PREFIX%%/*}"
    AFTER_SHARD="${AFTER_PREFIX#*/}"
    OLD_HASH="${AFTER_SHARD%%/*}"
  fi

  if [ "$OLD_HASH" = "$NEW_HASH" ]; then
    printf 'CURRENT: %s\n' "$OLD_RECORD_PATH"
    exit 0
  fi

  NEW_RECORD_DIR="$HASH_RECORD_ROOT/$NEW_SHARD/$NEW_HASH/$OP_KIND"
  NEW_RECORD_PATH="$NEW_RECORD_DIR/$RECORD_FILENAME"

  mkdir -p "$NEW_RECORD_DIR"

  OLD_REL="${OLD_RECORD_PATH#${REPO_ROOT}/}"
  NEW_REL="${NEW_RECORD_PATH#${REPO_ROOT}/}"

  git -C "$REPO_ROOT" mv "$OLD_REL" "$NEW_REL"

  printf 'REKEYED: %s\n' "$NEW_RECORD_PATH"
  exit 0
fi
