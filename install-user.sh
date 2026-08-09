#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
TARGET_AGENTS="$CODEX_DIR/agents"
TARGET_GLOBAL="$CODEX_DIR/AGENTS.md"
SOURCE_GLOBAL="$SCRIPT_DIR/global/AGENTS.md"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
INSTALL_GLOBAL=true
BEGIN_MARKER='<!-- BEGIN CODEX ENGINEERING TEAM -->'
END_MARKER='<!-- END CODEX ENGINEERING TEAM -->'

usage() {
  cat <<'USAGE'
Usage: ./install-user.sh [--agents-only]

  --agents-only  Install/update custom agent TOML files without modifying
                 the global ~/.codex/AGENTS.md operating agreement.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --agents-only) INSTALL_GLOBAL=false ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

backup_path() {
  local path="$1"
  cp "$path" "$path.bak.$STAMP"
  echo "Backed up: $path -> $path.bak.$STAMP"
}

sha256_file() {
  local path="$1"
  local digest_line

  if command -v shasum >/dev/null 2>&1; then
    digest_line="$(shasum -a 256 "$path")" || return 2
  elif command -v sha256sum >/dev/null 2>&1; then
    digest_line="$(sha256sum "$path")" || return 2
  else
    return 2
  fi

  printf '%s\n' "${digest_line%% *}"
}

legacy_matches_known_package() {
  local path="$1"
  shift
  local actual
  local expected

  actual="$(sha256_file "$path")" || return $?
  for expected in "$@"; do
    if [[ "$actual" == "$expected" ]]; then
      return 0
    fi
  done
  return 1
}

migrate_legacy_agent() {
  local legacy_name="$1"
  local canonical_name="$2"
  shift 2
  local legacy_path="$TARGET_AGENTS/$legacy_name"
  local canonical_path="$TARGET_AGENTS/$canonical_name.toml"
  local canonical_source="$SCRIPT_DIR/agents/$canonical_name.toml"
  local match_status

  if [[ ! -e "$legacy_path" && ! -L "$legacy_path" ]]; then
    return
  fi

  if [[ ! -f "$canonical_source" || -L "$canonical_source" || ! -f "$canonical_path" || -L "$canonical_path" ]] || ! cmp -s "$canonical_source" "$canonical_path"; then
    echo "WARNING: preserved legacy agent $legacy_path; migration skipped because a verified canonical replacement for $canonical_name is unavailable." >&2
    return
  fi

  if [[ ! -f "$legacy_path" || -L "$legacy_path" ]]; then
    echo "WARNING: preserved legacy agent $legacy_path; it is not a regular package file. Verified canonical $canonical_name is available, so no migration was performed." >&2
    return
  fi

  if legacy_matches_known_package "$legacy_path" "$@"; then
    backup_path "$legacy_path"
    rm "$legacy_path"
    echo "Deactivated legacy package agent: $legacy_path (backup retained; canonical $canonical_name installed)."
    return
  else
    match_status=$?
  fi

  if [[ "$match_status" == "2" ]]; then
    echo "WARNING: preserved legacy agent $legacy_path because package ownership could not be verified. Canonical $canonical_name was installed separately; review the legacy file manually." >&2
  else
    echo "WARNING: preserved legacy agent $legacy_path because its contents differ from known package revisions. Canonical $canonical_name was installed separately; review the legacy file manually." >&2
  fi
}

install_file() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ ! -f "$dst" || -L "$dst" ]]; then
      echo "WARNING: preserved canonical agent destination $dst; it is not a regular file. Skipping $label." >&2
      return
    fi

    if cmp -s "$src" "$dst"; then
      echo "Unchanged: $label"
      return
    fi

    backup_path "$dst"
  fi

  cp "$src" "$dst"
  echo "Installed: $label"
}

mkdir -p "$TARGET_AGENTS"
for src in "$SCRIPT_DIR"/agents/*.toml; do
  name="$(basename "$src")"
  install_file "$src" "$TARGET_AGENTS/$name" "agent $name"
done

# SHA-256 allowlists for package-owned legacy files from v1.2.0 (8da1150)
# and v1.2.1 (25d3b1e); unknown content remains user-owned and active.
migrate_legacy_agent "implementer.toml" "worker" \
  "29da73e7688d555f8441be6b5343bf0ea907e66a2d0afd355ec87a644f9a6f1b" \
  "7ef0ce8274db932712fc577528010a3402b291f8c859d9dfaf50cf436184c094"
migrate_legacy_agent "test_engineer.toml" "tester" \
  "fdff3a027c37848b8a4e41d7f6190dc8cf89a74ad7e97d02d54f2b4a12beebe7" \
  "fc24b481e1b72ec8e417e088a7c22bb75057020701bf1116bb5c67f8028f23f7"

if [[ "$INSTALL_GLOBAL" == true ]]; then
  mkdir -p "$CODEX_DIR"
  if [[ -e "$TARGET_GLOBAL" || -L "$TARGET_GLOBAL" ]]; then
    if [[ ! -f "$TARGET_GLOBAL" || -L "$TARGET_GLOBAL" ]]; then
      echo "Error: $TARGET_GLOBAL is not a regular file. No global instructions were changed." >&2
      echo "Repair the path or use --agents-only." >&2
      exit 1
    fi
  fi

  tmp="$(mktemp)"
  prefix_tmp=''
  suffix_tmp=''
  cleanup_tmp() {
    if [[ -n "$tmp" ]]; then
      rm -f "$tmp"
    fi
    if [[ -n "$prefix_tmp" ]]; then
      rm -f "$prefix_tmp"
    fi
    if [[ -n "$suffix_tmp" ]]; then
      rm -f "$suffix_tmp"
    fi
  }
  trap cleanup_tmp EXIT

  marker_info='NONE'
  if [[ -f "$TARGET_GLOBAL" ]]; then
    marker_status=0
    marker_info="$(awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
      BEGIN { state = 0; invalid = 0 }
      $0 == begin {
        if (state != 0) { invalid = 1; exit 2 }
        state = 1
        begin_line = NR
        next
      }
      $0 == end {
        if (state != 1) { invalid = 1; exit 2 }
        state = 2
        end_line = NR
        next
      }
      END {
        if (invalid || state == 1) { exit 2 }
        if (state == 0) {
          print "NONE"
        } else {
          printf "BLOCK %d %d\n", begin_line, end_line
        }
      }
    ' "$TARGET_GLOBAL")" || marker_status=$?

    if [[ "$marker_status" != "0" ]]; then
      echo "Error: $TARGET_GLOBAL contains unmatched or duplicate engineering-team markers (invalid ordered/non-nested block). Expected one ordered, non-nested BEGIN...END block or no markers." >&2
      echo "No global instructions were changed. Repair the markers or use --agents-only." >&2
      exit 1
    fi
  fi

  marker_kind="${marker_info%% *}"
  if [[ "$marker_kind" == "NONE" ]]; then
    if [[ -f "$TARGET_GLOBAL" ]]; then
      # With no markers, preserve the existing boundary behavior: retain user
      # content and normalize only trailing blank lines before appending.
      awk '
        {
          if ($0 ~ /^[[:space:]]*$/) { blanks++; next }
          while (blanks > 0) { print ""; blanks-- }
          print
        }
      ' "$TARGET_GLOBAL" > "$tmp"
    fi
    if [[ -s "$tmp" ]]; then
      printf '\n' >> "$tmp"
    fi
  elif [[ "$marker_kind" == "BLOCK" ]]; then
    marker_lines="${marker_info#BLOCK }"
    read -r begin_line end_line <<< "$marker_lines"
    prefix_tmp="$(mktemp)"
    suffix_tmp="$(mktemp)"
    if (( begin_line > 1 )); then
      head -n "$((begin_line - 1))" "$TARGET_GLOBAL" > "$prefix_tmp"
    else
      : > "$prefix_tmp"
    fi
    tail -n "+$((end_line + 1))" "$TARGET_GLOBAL" > "$suffix_tmp"
    cat "$prefix_tmp" > "$tmp"
  else
    echo "Error: could not classify marker state for $TARGET_GLOBAL. No global instructions were changed." >&2
    exit 1
  fi

  {
    printf '%s\n' "$BEGIN_MARKER"
    cat "$SOURCE_GLOBAL"
    printf '%s\n' "$END_MARKER"
  } >> "$tmp"

  if [[ "$marker_kind" == "BLOCK" ]]; then
    cat "$suffix_tmp" >> "$tmp"
  fi

  if [[ -f "$TARGET_GLOBAL" ]] && cmp -s "$tmp" "$TARGET_GLOBAL"; then
    echo "Unchanged: global team agreement"
  else
    if [[ -f "$TARGET_GLOBAL" ]]; then
      backup_path "$TARGET_GLOBAL"
    fi
    mv "$tmp" "$TARGET_GLOBAL"
    tmp=''
    echo "Installed/updated: $TARGET_GLOBAL"
  fi

  if [[ -s "$CODEX_DIR/AGENTS.override.md" ]]; then
    echo
    echo "WARNING: $CODEX_DIR/AGENTS.override.md is non-empty."
    echo "Codex loads that file instead of $TARGET_GLOBAL at global scope."
    echo "Merge the engineering-team block into the override or remove the override when appropriate."
  fi
fi

echo
echo "Codex home: $CODEX_DIR"
echo "Agents:    $TARGET_AGENTS"
if [[ "$INSTALL_GLOBAL" == true ]]; then
  echo "Global:    $TARGET_GLOBAL"
fi
echo "Config:    merge $SCRIPT_DIR/config-snippet.toml into $CODEX_DIR/config.toml if needed."
echo "Project:   copy $SCRIPT_DIR/project/AGENTS.md.template into each repo and fill in real project facts."
echo "Restart or open a new Codex session so instruction discovery and custom agents reload."
