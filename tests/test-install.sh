#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$BASH_SOURCE"
ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
INSTALLER="$ROOT_DIR/install-user.sh"
TMP_BASE="$(printenv TMPDIR 2>/dev/null || true)"
if [[ -z "$TMP_BASE" ]]; then
  TMP_BASE="/tmp"
fi
TMP_ROOT="$(mktemp -d "$TMP_BASE/codex-engineering-team-tests.XXXXXX")"
RUN_NUMBER=0
LAST_STDOUT=""
LAST_STDERR=""

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "ok - $*"
}

assert_file() {
  [[ -f "$1" ]] || fail "expected regular file: $1"
}

assert_path() {
  [[ -e "$1" || -L "$1" ]] || fail "expected path: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected path to be absent: $1"
}

assert_contains() {
  local needle="$1"
  local path="$2"
  grep -Fq "$needle" "$path" || fail "expected $(basename "$path") to contain: $needle"
}

assert_not_contains() {
  local needle="$1"
  local path="$2"
  if grep -Fq "$needle" "$path"; then
    fail "expected $(basename "$path") not to contain: $needle"
  fi
}

assert_same_file() {
  cmp -s "$1" "$2" || fail "files differ: $1 and $2"
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    fail "neither shasum nor sha256sum is available"
  fi
}

snapshot_tree() {
  local root="$1"
  local output="$2"
  (
    cd "$root"
    find . -type f -print | sort | while IFS= read -r path; do
      printf '%s ' "$path"
      sha256_file "$path"
      printf '\n'
    done
  ) > "$output"
}

backup_count() {
  find "$1" -type f -name '*.bak.*' -print | wc -l | tr -d ' '
}

run_install() {
  local label="$1"
  local home="$2"
  local run_id
  shift 2
  RUN_NUMBER=$((RUN_NUMBER + 1))
  run_id="$RUN_NUMBER-$label"
  LAST_STDOUT="$TMP_ROOT/$run_id.stdout"
  LAST_STDERR="$TMP_ROOT/$run_id.stderr"
  if ! CODEX_HOME="$home" "$INSTALLER" "$@" >"$LAST_STDOUT" 2>"$LAST_STDERR"; then
    echo "--- stdout ($label) ---" >&2
    cat "$LAST_STDOUT" >&2 || true
    echo "--- stderr ($label) ---" >&2
    cat "$LAST_STDERR" >&2 || true
    fail "installer failed: $label"
  fi
}

run_install_expect_failure() {
  local label="$1"
  local home="$2"
  local run_id
  shift 2
  RUN_NUMBER=$((RUN_NUMBER + 1))
  run_id="$RUN_NUMBER-$label"
  LAST_STDOUT="$TMP_ROOT/$run_id.stdout"
  LAST_STDERR="$TMP_ROOT/$run_id.stderr"
  if CODEX_HOME="$home" "$INSTALLER" "$@" >"$LAST_STDOUT" 2>"$LAST_STDERR"; then
    fail "installer unexpectedly succeeded: $label"
  fi
}

legacy_revision() {
  case "$1" in
    v1.2.0) printf '%s\n' '8da1150' ;;
    v1.2.1) printf '%s\n' '25d3b1e' ;;
    *) fail "unknown legacy revision: $1" ;;
  esac
}

legacy_hash() {
  case "$1:$2" in
    implementer.toml:v1.2.0) printf '%s\n' '29da73e7688d555f8441be6b5343bf0ea907e66a2d0afd355ec87a644f9a6f1b' ;;
    implementer.toml:v1.2.1) printf '%s\n' '7ef0ce8274db932712fc577528010a3402b291f8c859d9dfaf50cf436184c094' ;;
    test_engineer.toml:v1.2.0) printf '%s\n' 'fdff3a027c37848b8a4e41d7f6190dc8cf89a74ad7e97d02d54f2b4a12beebe7' ;;
    test_engineer.toml:v1.2.1) printf '%s\n' 'fc24b481e1b72ec8e417e088a7c22bb75057020701bf1116bb5c67f8028f23f7' ;;
    *) fail "unknown legacy fixture: $1 $2" ;;
  esac
}

canonical_for_legacy() {
  case "$1" in
    implementer.toml) printf '%s\n' 'worker.toml' ;;
    test_engineer.toml) printf '%s\n' 'tester.toml' ;;
    *) fail "unknown legacy role: $1" ;;
  esac
}

write_legacy_fixture() {
  local revision="$1"
  local legacy="$2"
  local destination="$3"
  local commit
  commit="$(legacy_revision "$revision")"
  if ! git -C "$ROOT_DIR" show "$commit:agents/$legacy" > "$destination"; then
    fail "cannot load legacy fixture $revision agents/$legacy from repository history"
  fi
  [[ "$(sha256_file "$destination")" == "$(legacy_hash "$legacy" "$revision")" ]] || \
    fail "legacy fixture hash mismatch: $revision agents/$legacy"
}

parse_tomls() {
  local agents_dir="$1"
  local config_path="$2"
  python3 - "$agents_dir" "$config_path" <<'PY'
import pathlib
import sys
import tomllib

agents_dir = pathlib.Path(sys.argv[1])
config_path = pathlib.Path(sys.argv[2])
expected = {
    "explorer": ("gpt-5.6-terra", "high", "read-only"),
    "architect": ("gpt-5.6-sol", "xhigh", "read-only"),
    "worker": ("gpt-5.6-luna", "max", "workspace-write"),
    "tester": ("gpt-5.6-luna", "max", "workspace-write"),
    "reviewer": ("gpt-5.6-sol", "xhigh", "read-only"),
    "debugger": ("gpt-5.6-sol", "xhigh", "workspace-write"),
    "git_operator": ("gpt-5.6-luna", "high", "workspace-write"),
}

actual_files = {path.stem for path in agents_dir.glob("*.toml")}
if actual_files != set(expected):
    raise SystemExit(f"agent filenames: expected {set(expected)!r}, got {actual_files!r}")

for name, (model, effort, sandbox) in expected.items():
    path = agents_dir / f"{name}.toml"
    data = tomllib.loads(path.read_text())
    if data.get("name") != name:
        raise SystemExit(f"{path}: name is {data.get('name')!r}")
    if data.get("model") != model:
        raise SystemExit(f"{path}: model is {data.get('model')!r}")
    if data.get("model_reasoning_effort") != effort:
        raise SystemExit(f"{path}: effort is {data.get('model_reasoning_effort')!r}")
    if data.get("sandbox_mode") != sandbox:
        raise SystemExit(f"{path}: sandbox is {data.get('sandbox_mode')!r}")
    if not isinstance(data.get("developer_instructions"), str) or not data["developer_instructions"].strip():
        raise SystemExit(f"{path}: missing developer_instructions")

config = tomllib.loads(config_path.read_text())
if set(config) != {"model", "model_reasoning_effort", "features", "agents"}:
    raise SystemExit(f"config top-level keys: {set(config)!r}")
if config["model"] != "gpt-5.6-sol" or config["model_reasoning_effort"] != "max":
    raise SystemExit("config Main model/effort are not Sol/max")
if config["features"] != {"multi_agent_v2": True}:
    raise SystemExit(f"config feature settings: {config['features']!r}")
if set(config["agents"]) != {"enabled", "interrupt_message"}:
    raise SystemExit(f"config agent keys: {set(config['agents'])!r}")
if config["agents"] != {"enabled": True, "interrupt_message": True}:
    raise SystemExit(f"config agent settings: {config['agents']!r}")
PY
}

check_documented_runtime_semantics() {
  local readme="$ROOT_DIR/README.md"
  local global="$ROOT_DIR/global/AGENTS.md"
  assert_contains 'fork_turns' "$global"
  assert_contains 'sandbox_mode' "$global"
  assert_contains 'configured defaults' "$readme"
  assert_contains 'permission envelope' "$readme"
  assert_contains 'Multi-agent V2 runtime' "$readme"
  assert_contains 'Runtime selection also chooses concurrency' "$readme"
  assert_contains 'concurrency' "$global"
  assert_contains 'expected to exceed the prompt and handoff overhead' "$global"
  assert_contains 'compose only the gates that the task needs' "$global"
  assert_contains 'expected latency or evidence benefit exceeds the delegation and synthesis cost' "$global"
  assert_contains 'the full pipeline is not the default' "$readme"
}

check_cost_aware_verification_routing() {
  local tester="$ROOT_DIR/agents/tester.toml"
  local debugger="$ROOT_DIR/agents/debugger.toml"
  local readme="$ROOT_DIR/README.md"
  local global="$ROOT_DIR/global/AGENTS.md"
  local prompts="$ROOT_DIR/sample-prompts.md"

  assert_contains 'Independent behavioral verification specialist' "$tester"
  assert_contains '## Test Result' "$tester"
  assert_contains '**Verdict:** PASS | FAIL | INCONCLUSIVE' "$tester"
  assert_contains 'Map each material acceptance criterion' "$tester"
  assert_contains 'plausible production defect' "$tester"
  assert_contains 'Apply verdicts in this order: `FAIL`, then `INCONCLUSIVE`, then `PASS`' "$tester"
  assert_contains '`PASS` only when every material acceptance criterion has sufficient evidence' "$tester"
  assert_contains '`FAIL` when required observable behavior is disproven' "$tester"
  assert_contains '`INCONCLUSIVE` when any material acceptance criterion lacks sufficient evidence' "$tester"
  assert_contains 'Successful verification returns to `parent`' "$tester"
  assert_contains 'does not perform or replace independent code, architecture, or security review' "$tester"
  assert_contains 'Do not automatically chain `tester` to `reviewer`' "$global"
  assert_contains 'alternatives for ordinary changes' "$global"
  assert_contains 'high-risk and each gate addresses a distinct material uncertainty' "$global"
  assert_contains 'behavioral compatibility' "$global"
  assert_contains 'high-risk and the two gates address distinct material uncertainties' "$debugger"
  assert_contains 'Route successful production work to `tester` for behavioral verification' "$ROOT_DIR/agents/worker.toml"
  assert_contains '`tester` can serve as the acceptance gate' "$readme"
  assert_contains 'reviewer only for material non-behavioral risk' "$prompts"

  assert_not_contains '## Verification Result' "$tester"
  assert_not_contains 'Successful test work normally routes to a fresh `reviewer`' "$tester"
  assert_not_contains 'route to `tester` and then a fresh `reviewer`' "$debugger"
  assert_not_contains 'Use both only when their evidence is materially distinct.' "$global"
}

check_active_legacy_names_are_bounded() {
  local path
  for path in "$ROOT_DIR"/agents/*.toml "$ROOT_DIR/global/AGENTS.md" "$ROOT_DIR/config-snippet.toml" "$ROOT_DIR/project/AGENTS.md.template" "$ROOT_DIR/sample-prompts.md"; do
    assert_not_contains 'implementer' "$path"
    assert_not_contains 'test_engineer' "$path"
  done
  assert_contains 'migrate_legacy_agent "implementer.toml" "worker"' "$INSTALLER"
  assert_contains 'migrate_legacy_agent "test_engineer.toml" "tester"' "$INSTALLER"
}

echo "Checking syntax, TOML contracts, and documentation..."
bash -n "$INSTALLER"
bash -n "$SCRIPT_PATH"
parse_tomls "$ROOT_DIR/agents" "$ROOT_DIR/config-snippet.toml"
check_documented_runtime_semantics
check_cost_aware_verification_routing
check_active_legacy_names_are_bounded
pass "shell syntax, canonical role contracts, config semantics, and bounded legacy names"

echo "Checking fresh install and normal global marker installation..."
FRESH_HOME="$TMP_ROOT/fresh-home"
mkdir -p "$FRESH_HOME"
run_install fresh "$FRESH_HOME"
for role in explorer architect worker tester reviewer debugger git_operator; do
  assert_file "$FRESH_HOME/agents/$role.toml"
done
assert_absent "$FRESH_HOME/agents/implementer.toml"
assert_absent "$FRESH_HOME/agents/test_engineer.toml"
assert_file "$FRESH_HOME/AGENTS.md"
assert_absent "$FRESH_HOME/config.toml"
parse_tomls "$FRESH_HOME/agents" "$ROOT_DIR/config-snippet.toml"
[[ "$(grep -Fxc '<!-- BEGIN CODEX ENGINEERING TEAM -->' "$FRESH_HOME/AGENTS.md")" == 1 ]] || fail "fresh install marker count"
[[ "$(grep -Fxc '<!-- END CODEX ENGINEERING TEAM -->' "$FRESH_HOME/AGENTS.md")" == 1 ]] || fail "fresh install marker count"
awk '/^<!-- BEGIN CODEX ENGINEERING TEAM -->$/{inside=1; next} /^<!-- END CODEX ENGINEERING TEAM -->$/{inside=0} inside{print}' "$FRESH_HOME/AGENTS.md" > "$TMP_ROOT/fresh-global-block"
assert_same_file "$ROOT_DIR/global/AGENTS.md" "$TMP_ROOT/fresh-global-block"
[[ "$(backup_count "$FRESH_HOME")" == 0 ]] || fail "fresh install unexpectedly created backups"
pass "fresh install creates exactly the seven canonical roles and one managed global block"

snapshot_tree "$FRESH_HOME" "$TMP_ROOT/fresh-before-reinstall"
run_install fresh-reinstall "$FRESH_HOME"
snapshot_tree "$FRESH_HOME" "$TMP_ROOT/fresh-after-reinstall"
assert_same_file "$TMP_ROOT/fresh-before-reinstall" "$TMP_ROOT/fresh-after-reinstall"
[[ "$(backup_count "$FRESH_HOME")" == 0 ]] || fail "idempotent reinstall unexpectedly created backups"
pass "reinstall is idempotent"

echo "Checking normal global block replacement and malformed-marker safety..."
MARKER_HOME="$TMP_ROOT/marker-home"
mkdir -p "$MARKER_HOME/agents"
cat > "$MARKER_HOME/AGENTS.md" <<'EOF'
User instructions before the managed block.

<!-- BEGIN CODEX ENGINEERING TEAM -->
stale package content
<!-- END CODEX ENGINEERING TEAM -->

User instructions after the managed block.
EOF
cp "$MARKER_HOME/AGENTS.md" "$TMP_ROOT/old-marker-global"
run_install marker "$MARKER_HOME"
assert_contains 'User instructions before the managed block.' "$MARKER_HOME/AGENTS.md"
assert_contains 'User instructions after the managed block.' "$MARKER_HOME/AGENTS.md"
assert_contains 'Deliver the smallest correct change' "$MARKER_HOME/AGENTS.md"
[[ "$(grep -Fxc '<!-- BEGIN CODEX ENGINEERING TEAM -->' "$MARKER_HOME/AGENTS.md")" == 1 ]] || fail "replacement begin marker count"
[[ "$(grep -Fxc '<!-- END CODEX ENGINEERING TEAM -->' "$MARKER_HOME/AGENTS.md")" == 1 ]] || fail "replacement end marker count"
awk '/^<!-- BEGIN CODEX ENGINEERING TEAM -->$/{inside=1; next} /^<!-- END CODEX ENGINEERING TEAM -->$/{inside=0} inside{print}' "$MARKER_HOME/AGENTS.md" > "$TMP_ROOT/replaced-global-block"
assert_same_file "$ROOT_DIR/global/AGENTS.md" "$TMP_ROOT/replaced-global-block"
old_marker_backup="$(find "$MARKER_HOME" -type f -name 'AGENTS.md.bak.*' -print | head -1)"
assert_file "$old_marker_backup"
assert_same_file "$TMP_ROOT/old-marker-global" "$old_marker_backup"
snapshot_tree "$MARKER_HOME" "$TMP_ROOT/marker-before-reinstall"
run_install marker-reinstall "$MARKER_HOME"
snapshot_tree "$MARKER_HOME" "$TMP_ROOT/marker-after-reinstall"
assert_same_file "$TMP_ROOT/marker-before-reinstall" "$TMP_ROOT/marker-after-reinstall"
pass "normal install replaces only the managed block and preserves unrelated global content"

EXACT_MARKER_HOME="$TMP_ROOT/exact-marker-home"
mkdir -p "$EXACT_MARKER_HOME"
printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
  'prefix-first' \
  'prefix-second' \
  '<!-- BEGIN CODEX ENGINEERING TEAM -->' \
  'stale package content' \
  '<!-- END CODEX ENGINEERING TEAM -->' \
  'suffix-first' > "$EXACT_MARKER_HOME/AGENTS.md"
printf '%s' 'suffix-final-no-newline' >> "$EXACT_MARKER_HOME/AGENTS.md"
run_install exact-marker "$EXACT_MARKER_HOME"
python3 - "$EXACT_MARKER_HOME/AGENTS.md" "$ROOT_DIR/global/AGENTS.md" <<'PY'
from pathlib import Path
import sys

target = Path(sys.argv[1]).read_bytes()
source = Path(sys.argv[2]).read_bytes()
begin = b"<!-- BEGIN CODEX ENGINEERING TEAM -->\n"
end = b"<!-- END CODEX ENGINEERING TEAM -->\n"
prefix, remainder = target.split(begin, 1)
managed, suffix = remainder.split(end, 1)
assert prefix == b"prefix-first\nprefix-second\n", prefix
assert managed == source, (len(managed), len(source))
assert suffix == b"suffix-first\nsuffix-final-no-newline", suffix
assert target.count(begin) == 1
assert target.count(end) == 1
PY
snapshot_tree "$EXACT_MARKER_HOME" "$TMP_ROOT/exact-marker-before-reinstall"
run_install exact-marker-reinstall "$EXACT_MARKER_HOME"
snapshot_tree "$EXACT_MARKER_HOME" "$TMP_ROOT/exact-marker-after-reinstall"
assert_same_file "$TMP_ROOT/exact-marker-before-reinstall" "$TMP_ROOT/exact-marker-after-reinstall"
pass "valid managed blocks preserve exact prefix/suffix bytes, including a no-final-newline suffix, and remain idempotent"

echo "Checking malformed marker layouts fail closed..."
for layout in reversed nested duplicate unmatched-begin unmatched-end; do
  BAD_HOME="$TMP_ROOT/bad-markers-$layout"
  mkdir -p "$BAD_HOME"
  case "$layout" in
    reversed)
      printf '%s\n%s\n%s\n' \
        '<!-- END CODEX ENGINEERING TEAM -->' \
        'reversed marker payload' \
        '<!-- BEGIN CODEX ENGINEERING TEAM -->' > "$BAD_HOME/AGENTS.md"
      ;;
    nested)
      printf '%s\n%s\n%s\n%s\n' \
        '<!-- BEGIN CODEX ENGINEERING TEAM -->' \
        'outer payload' \
        '<!-- BEGIN CODEX ENGINEERING TEAM -->' \
        '<!-- END CODEX ENGINEERING TEAM -->' > "$BAD_HOME/AGENTS.md"
      ;;
    duplicate)
      printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
        '<!-- BEGIN CODEX ENGINEERING TEAM -->' \
        'first payload' \
        '<!-- END CODEX ENGINEERING TEAM -->' \
        '<!-- BEGIN CODEX ENGINEERING TEAM -->' \
        'second payload' \
        '<!-- END CODEX ENGINEERING TEAM -->' > "$BAD_HOME/AGENTS.md"
      ;;
    unmatched-begin)
      printf '%s\n%s' \
        '<!-- BEGIN CODEX ENGINEERING TEAM -->' \
        'unmatched begin payload' > "$BAD_HOME/AGENTS.md"
      ;;
    unmatched-end)
      printf '%s\n%s' \
        '<!-- END CODEX ENGINEERING TEAM -->' \
        'unmatched end payload' > "$BAD_HOME/AGENTS.md"
      ;;
  esac
  cp "$BAD_HOME/AGENTS.md" "$TMP_ROOT/bad-global-before-$layout"
  run_install_expect_failure "bad-markers-$layout" "$BAD_HOME"
  assert_same_file "$TMP_ROOT/bad-global-before-$layout" "$BAD_HOME/AGENTS.md"
  assert_contains 'invalid ordered/non-nested block' "$LAST_STDERR"
  [[ "$(backup_count "$BAD_HOME")" == 0 ]] || fail "malformed $layout unexpectedly created a backup"
  pass "malformed $layout markers preserve AGENTS.md byte-for-byte"
done

echo "Checking --agents-only boundary..."
AGENTS_ONLY_HOME="$TMP_ROOT/agents-only-home"
mkdir -p "$AGENTS_ONLY_HOME"
printf 'user global instructions\n' > "$AGENTS_ONLY_HOME/AGENTS.md"
printf 'user config\n' > "$AGENTS_ONLY_HOME/config.toml"
cp "$AGENTS_ONLY_HOME/AGENTS.md" "$TMP_ROOT/agents-only-global-before"
cp "$AGENTS_ONLY_HOME/config.toml" "$TMP_ROOT/agents-only-config-before"
run_install agents-only "$AGENTS_ONLY_HOME" --agents-only
assert_same_file "$TMP_ROOT/agents-only-global-before" "$AGENTS_ONLY_HOME/AGENTS.md"
assert_same_file "$TMP_ROOT/agents-only-config-before" "$AGENTS_ONLY_HOME/config.toml"
assert_absent "$AGENTS_ONLY_HOME/AGENTS.override.md"
parse_tomls "$AGENTS_ONLY_HOME/agents" "$ROOT_DIR/config-snippet.toml"
if grep -Fq 'Global:' "$LAST_STDOUT"; then
  fail "--agents-only output claims to install global instructions"
fi
pass "--agents-only leaves global AGENTS.md and config.toml untouched"

echo "Checking nonregular canonical destinations..."
for symlink_role in worker tester; do
  if [[ "$symlink_role" == worker ]]; then
    directory_role=tester
  else
    directory_role=worker
  fi
  NONREGULAR_CANONICAL_HOME="$TMP_ROOT/nonregular-canonical-$symlink_role"
  mkdir -p "$NONREGULAR_CANONICAL_HOME/agents"
  sentinel="$NONREGULAR_CANONICAL_HOME/external-sentinel"
  directory_payload="$NONREGULAR_CANONICAL_HOME/directory-payload"
  printf 'external sentinel must not change\n' > "$sentinel"
  printf 'directory payload must not change\n' > "$directory_payload"
  cp "$sentinel" "$TMP_ROOT/sentinel-before-$symlink_role"
  cp "$directory_payload" "$TMP_ROOT/directory-payload-before-$symlink_role"
  ln -s "$sentinel" "$NONREGULAR_CANONICAL_HOME/agents/$symlink_role.toml"
  mkdir "$NONREGULAR_CANONICAL_HOME/agents/$directory_role.toml"
  cp "$directory_payload" "$NONREGULAR_CANONICAL_HOME/agents/$directory_role.toml/payload"
  run_install "nonregular-canonical-$symlink_role" "$NONREGULAR_CANONICAL_HOME" --agents-only
  [[ -L "$NONREGULAR_CANONICAL_HOME/agents/$symlink_role.toml" ]] || fail "canonical symlink destination was replaced"
  [[ "$(readlink "$NONREGULAR_CANONICAL_HOME/agents/$symlink_role.toml")" == "$sentinel" ]] || fail "canonical symlink target changed"
  assert_same_file "$TMP_ROOT/sentinel-before-$symlink_role" "$sentinel"
  [[ -d "$NONREGULAR_CANONICAL_HOME/agents/$directory_role.toml" ]] || fail "canonical directory destination was replaced"
  assert_same_file "$TMP_ROOT/directory-payload-before-$symlink_role" "$NONREGULAR_CANONICAL_HOME/agents/$directory_role.toml/payload"
  assert_contains "preserved canonical agent destination $NONREGULAR_CANONICAL_HOME/agents/$symlink_role.toml" "$LAST_STDERR"
  assert_contains "preserved canonical agent destination $NONREGULAR_CANONICAL_HOME/agents/$directory_role.toml" "$LAST_STDERR"
  for role in explorer architect reviewer debugger git_operator; do
    assert_file "$NONREGULAR_CANONICAL_HOME/agents/$role.toml"
  done
  [[ "$(backup_count "$NONREGULAR_CANONICAL_HOME")" == 0 ]] || fail "nonregular canonical destinations unexpectedly created backups"
  pass "canonical $symlink_role symlink and $directory_role directory are preserved while other roles install"
done

echo "Checking legacy migration waits for a verified canonical replacement..."
run_migration_with_unsafe_canonical() {
  local legacy="$1"
  local canonical="$2"
  local unsafe_kind="$3"
  local label="$4"
  local home="$TMP_ROOT/migration-order-$label"
  local fixture="$TMP_ROOT/migration-order-$label-$legacy"
  local unsafe_path="$home/agents/$canonical.toml"
  local sentinel="$home/external-sentinel"
  local directory_payload="$home/directory-payload"
  local role

  mkdir -p "$home/agents"
  write_legacy_fixture v1.2.1 "$legacy" "$fixture"
  cp "$fixture" "$home/agents/$legacy"
  cp "$home/agents/$legacy" "$TMP_ROOT/migration-order-before-$label"
  printf 'external migration sentinel must not change\n' > "$sentinel"
  cp "$sentinel" "$TMP_ROOT/migration-order-sentinel-before-$label"
  if [[ "$unsafe_kind" == symlink ]]; then
    ln -s "$sentinel" "$unsafe_path"
  else
    printf 'canonical directory payload must not change\n' > "$directory_payload"
    mkdir "$unsafe_path"
    cp "$directory_payload" "$unsafe_path/payload"
    cp "$directory_payload" "$TMP_ROOT/migration-order-directory-before-$label"
  fi

  run_install "migration-order-$label" "$home" --agents-only
  assert_same_file "$TMP_ROOT/migration-order-before-$label" "$home/agents/$legacy"
  assert_path "$home/agents/$legacy"
  [[ "$(find "$home/agents" -type f -name "$legacy.bak.*" -print | wc -l | tr -d ' ')" == 0 ]] || fail "$legacy was backed up despite unavailable canonical replacement"
  assert_not_contains 'Deactivated legacy package agent' "$LAST_STDOUT"
  assert_contains "migration skipped because a verified canonical replacement for $canonical is unavailable" "$LAST_STDERR"

  if [[ "$unsafe_kind" == symlink ]]; then
    [[ -L "$unsafe_path" ]] || fail "unsafe canonical symlink was replaced before migration"
    [[ "$(readlink "$unsafe_path")" == "$sentinel" ]] || fail "unsafe canonical symlink target changed before migration"
    assert_same_file "$TMP_ROOT/migration-order-sentinel-before-$label" "$sentinel"
  else
    [[ -d "$unsafe_path" ]] || fail "unsafe canonical directory was replaced before migration"
    assert_same_file "$TMP_ROOT/migration-order-directory-before-$label" "$unsafe_path/payload"
  fi

  for role in explorer architect worker tester reviewer debugger git_operator; do
    if [[ "$role" != "$canonical" ]]; then
      assert_file "$home/agents/$role.toml"
    fi
  done
  pass "v1.2.1 $legacy remains active when canonical $canonical is an unsafe $unsafe_kind"
}

run_migration_with_unsafe_canonical implementer.toml worker symlink implementer-worker-symlink
run_migration_with_unsafe_canonical implementer.toml worker directory implementer-worker-directory
run_migration_with_unsafe_canonical test_engineer.toml tester symlink test-engineer-tester-symlink
run_migration_with_unsafe_canonical test_engineer.toml tester directory test-engineer-tester-directory

echo "Checking canonical copy failure leaves legacy roles untouched..."
COPY_FAILURE_HOME="$TMP_ROOT/canonical-copy-failure-home"
mkdir -p "$COPY_FAILURE_HOME/agents"
for legacy in implementer.toml test_engineer.toml; do
  fixture="$TMP_ROOT/canonical-copy-failure-$legacy"
  write_legacy_fixture v1.2.1 "$legacy" "$fixture"
  cp "$fixture" "$COPY_FAILURE_HOME/agents/$legacy"
  cp "$fixture" "$TMP_ROOT/canonical-copy-failure-before-$legacy"
done
REAL_CP="$(command -v cp)"
COPY_FAILURE_SHIM="$TMP_ROOT/canonical-copy-failure-shim"
mkdir -p "$COPY_FAILURE_SHIM"
{
  printf '%s\n' '#!/bin/sh' 'last=""' 'for arg in "$@"; do' '  last="$arg"' 'done'
  printf '%s\n' 'case "$last" in' '  */worker.toml)' '    echo "simulated canonical copy failure" >&2' '    exit 77' '    ;;' 'esac'
  printf 'exec "%s" "$@"\n' "$REAL_CP"
} > "$COPY_FAILURE_SHIM/cp"
chmod +x "$COPY_FAILURE_SHIM/cp"
ORIGINAL_PATH="$PATH"
PATH="$COPY_FAILURE_SHIM:$PATH"
run_install_expect_failure canonical-copy-failure "$COPY_FAILURE_HOME" --agents-only
PATH="$ORIGINAL_PATH"
for legacy in implementer.toml test_engineer.toml; do
  assert_same_file "$TMP_ROOT/canonical-copy-failure-before-$legacy" "$COPY_FAILURE_HOME/agents/$legacy"
  assert_path "$COPY_FAILURE_HOME/agents/$legacy"
  [[ "$(find "$COPY_FAILURE_HOME/agents" -type f -name "$legacy.bak.*" -print | wc -l | tr -d ' ')" == 0 ]] || fail "$legacy was migrated after canonical copy failure"
done
assert_contains 'simulated canonical copy failure' "$LAST_STDERR"
assert_not_contains 'Deactivated legacy package agent' "$LAST_STDOUT"
assert_absent "$COPY_FAILURE_HOME/agents/worker.toml"
pass "canonical copy failure stops before any legacy migration"

echo "Checking exact package-owned legacy migration revisions..."
for revision in v1.2.0 v1.2.1; do
  for legacy in implementer.toml test_engineer.toml; do
    home="$TMP_ROOT/migrate-$revision-$(basename "$legacy" .toml)"
    mkdir -p "$home/agents"
    fixture="$TMP_ROOT/$revision-$legacy"
    write_legacy_fixture "$revision" "$legacy" "$fixture"
    cp "$fixture" "$home/agents/$legacy"
    printf 'must remain untouched\n' > "$home/AGENTS.md"
    cp "$home/AGENTS.md" "$TMP_ROOT/$revision-$legacy-global-before"
    run_install "migrate-$revision-$legacy" "$home" --agents-only
    assert_absent "$home/agents/$legacy"
    canonical="$(canonical_for_legacy "$legacy")"
    assert_file "$home/agents/$canonical"
    backup="$(find "$home/agents" -type f -name "$legacy.bak.*" -print | head -1)"
    assert_file "$backup"
    assert_same_file "$fixture" "$backup"
    backup_name="$(basename "$backup")"
    [[ "$backup_name" == "$legacy".bak.????????-??????-* ]] || fail "backup is not timestamped: $backup_name"
    assert_same_file "$TMP_ROOT/$revision-$legacy-global-before" "$home/AGENTS.md"
    assert_contains 'Deactivated legacy package agent' "$LAST_STDOUT"
    pass "migrates package-owned $legacy from $revision with a timestamped backup"
  done
done

echo "Checking modified and nonregular legacy preservation..."
MODIFIED_HOME="$TMP_ROOT/modified-legacy-home"
mkdir -p "$MODIFIED_HOME/agents"
for legacy in implementer.toml test_engineer.toml; do
  fixture="$TMP_ROOT/modified-$legacy"
  write_legacy_fixture v1.2.1 "$legacy" "$fixture"
  printf '\n# user-owned modification\n' >> "$fixture"
  cp "$fixture" "$MODIFIED_HOME/agents/$legacy"
  cp "$fixture" "$TMP_ROOT/modified-before-$legacy"
done
printf 'custom agent owned by the user\n' > "$MODIFIED_HOME/agents/custom.toml"
cp "$MODIFIED_HOME/agents/custom.toml" "$TMP_ROOT/custom-before"
run_install modified-legacy "$MODIFIED_HOME" --agents-only
for legacy in implementer.toml test_engineer.toml; do
  assert_same_file "$TMP_ROOT/modified-before-$legacy" "$MODIFIED_HOME/agents/$legacy"
  assert_contains "preserved legacy agent $MODIFIED_HOME/agents/$legacy" "$LAST_STDERR"
  assert_contains 'contents differ from known package revisions' "$LAST_STDERR"
  [[ "$(find "$MODIFIED_HOME/agents" -type f -name "$legacy.bak.*" -print | wc -l | tr -d ' ')" == 0 ]] || fail "modified $legacy was backed up/deactivated"
done
assert_same_file "$TMP_ROOT/custom-before" "$MODIFIED_HOME/agents/custom.toml"
assert_file "$MODIFIED_HOME/agents/worker.toml"
assert_file "$MODIFIED_HOME/agents/tester.toml"
pass "modified regular legacy files and unrelated custom agents are preserved with warnings"

echo "Checking digest ownership-verification failure..."
DIGEST_FAILURE_HOME="$TMP_ROOT/digest-failure-home"
mkdir -p "$DIGEST_FAILURE_HOME/agents"
DIGEST_FAILURE_FIXTURE="$TMP_ROOT/digest-failure-implementer.toml"
write_legacy_fixture v1.2.1 implementer.toml "$DIGEST_FAILURE_FIXTURE"
cp "$DIGEST_FAILURE_FIXTURE" "$DIGEST_FAILURE_HOME/agents/implementer.toml"
cp "$DIGEST_FAILURE_HOME/agents/implementer.toml" "$TMP_ROOT/digest-failure-before"
DIGEST_SHIM="$TMP_ROOT/digest-shim"
mkdir -p "$DIGEST_SHIM"
cat > "$DIGEST_SHIM/shasum" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$DIGEST_SHIM/shasum"
ORIGINAL_PATH="$PATH"
PATH="$DIGEST_SHIM:$PATH"
run_install digest-failure "$DIGEST_FAILURE_HOME" --agents-only
PATH="$ORIGINAL_PATH"
assert_same_file "$TMP_ROOT/digest-failure-before" "$DIGEST_FAILURE_HOME/agents/implementer.toml"
assert_contains "preserved legacy agent $DIGEST_FAILURE_HOME/agents/implementer.toml because package ownership could not be verified" "$LAST_STDERR"
assert_not_contains 'contents differ from known package revisions' "$LAST_STDERR"
[[ "$(find "$DIGEST_FAILURE_HOME/agents" -type f -name 'implementer.toml.bak.*' -print | wc -l | tr -d ' ')" == 0 ]] || fail "digest failure unexpectedly deactivated legacy file"
assert_file "$DIGEST_FAILURE_HOME/agents/worker.toml"
pass "digest computation failure preserves legacy ownership and emits the verification warning"

NONREGULAR_HOME="$TMP_ROOT/nonregular-legacy-home"
mkdir -p "$NONREGULAR_HOME/agents/implementer.toml"
printf 'legacy directory payload\n' > "$NONREGULAR_HOME/agents/implementer.toml/payload"
printf 'legacy symlink target\n' > "$NONREGULAR_HOME/legacy-target"
ln -s "$NONREGULAR_HOME/legacy-target" "$NONREGULAR_HOME/agents/test_engineer.toml"
run_install nonregular-legacy "$NONREGULAR_HOME" --agents-only
[[ -d "$NONREGULAR_HOME/agents/implementer.toml" ]] || fail "legacy directory was not preserved"
[[ -L "$NONREGULAR_HOME/agents/test_engineer.toml" ]] || fail "legacy symlink was not preserved"
assert_contains 'not a regular package file' "$LAST_STDERR"
assert_file "$NONREGULAR_HOME/agents/worker.toml"
assert_file "$NONREGULAR_HOME/agents/tester.toml"
pass "nonregular legacy paths are preserved with warnings"

echo "All installer tests passed."
