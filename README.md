# Codex Engineering Team

**Version 2.0.0** — renames the public implementation and test roles to `worker` and `tester`, respectively, and adds safe migration for package-owned v1.2 legacy files. This is a breaking role-name change; the major version makes that contract change explicit.

A deliberately small Codex subagent team optimized for **simple, long-lived, robust, elegant engineering without over-design**.

> Using Claude Code instead? [**claude-engineering-team**](https://github.com/tonyzhoup/claude-engineering-team) is the same team contract, handoff envelope, and packet format ported to Claude Code subagents.

## Team

| Agent | Model / effort | Access | Responsibility |
|---|---|---|---|
| `explorer` | GPT-5.6 Terra / high | read-only | Repository facts, execution paths, ownership, impact |
| `architect` | GPT-5.6 Sol / xhigh | read-only | Minimal durable decisions and implementation packets |
| `worker` | GPT-5.6 Luna / max | workspace-write | Bounded production-code implementation |
| `tester` | GPT-5.6 Luna / max | workspace-write | Independent requirement-driven tests; test-only behavior |
| `reviewer` | GPT-5.6 Sol / xhigh | read-only | Architecture, code, and acceptance gates |
| `debugger` | GPT-5.6 Sol / xhigh | workspace-write | Difficult root-cause debugging and minimal fixes |
| `git_operator` | GPT-5.6 Luna / high | workspace-write | Precise repository-state and Git-history operations |

The primary Codex thread is the supervisor. There is no permanent supervisor agent and no workflow database.

The seven custom roles keep these per-role model and reasoning pins. The supplied config snippet separately sets the static Main supervisor baseline to GPT-5.6 Sol with `max` reasoning. A task or session may opt into Ultra through the runtime when that choice is available; that is an explicit runtime selection, not a package-wide default. Runtime selection also chooses concurrency per task/session; this package does not set a fixed concurrency limit.

The `worker` and `explorer` files are custom definitions at names that may also exist as built-ins, so the custom files shadow the built-ins wherever Codex gives user custom agents precedence. The `sandbox_mode` values in the table are configured defaults within the parent/runtime permission envelope, not guarantees that the package can override a live parent permission. Read-only roles retain their behavioral no-edit rule; a write role that receives effective read-only access must report `ENVIRONMENT_BLOCKER` instead of editing.

## Where the contracts live

```text
~/.codex/
├── AGENTS.md          # when to delegate, routing, gates, escalation, done criteria
├── agents/            # each role's authority, expected input, and output spec
│   └── *.toml         #   (handoff / packet templates live here)
└── config.toml        # multi-agent runtime settings

<repo>/
└── AGENTS.md          # repo layout, commands, conventions, constraints, done criteria
```

The global file says **how the team collaborates**. Each TOML says **how that role works and what shape it emits**. A repository `AGENTS.md` says **how this codebase works**.

Contracts are split by who needs them: routing, gates, and the delegation rule stay global because the primary thread uses them; the handoff and packet templates are output specs, so they live with the roles that produce them. A side effect is that `--agents-only` installs still emit correctly formatted handoffs.

Handoffs remain in the subagent response by default. Do not create per-task files unless you intentionally need cross-session persistence or an audit trail.

## Install

From this directory:

```bash
./install-user.sh
```

The installer:

1. installs the seven canonical TOML files, backing up only changed same-named files under `${CODEX_HOME:-~/.codex}/agents/`;
2. safely migrates package-owned legacy `implementer.toml` and `test_engineer.toml` files when their contents match a known v1.2 package revision; differing user files are preserved with a warning;
3. appends or replaces one clearly marked block in global `AGENTS.md`, backing it up only when content changes;
4. leaves `config.toml` untouched and tells you how to merge the supplied snippet.

Run only the agent-file installation with:

```bash
./install-user.sh --agents-only
```

If a non-empty `~/.codex/AGENTS.override.md` exists, Codex uses it instead of the global `AGENTS.md`; the installer warns rather than changing the override.

### Legacy role migration

The v2.0.0 installer recognizes the exact package-owned legacy files shipped in v1.2.0 and v1.2.1. It backs each matching legacy file up using the install timestamp, deactivates the old `.toml` path, and installs the canonical role. A modified legacy file is never deleted or overwritten; it stays in place and produces a clear warning so its owner can migrate it deliberately. Re-running the installer is idempotent, does not touch arbitrary agent files, and applies the same migration when `--agents-only` is used.

## Add project facts

Copy the template into a repository and fill it with actual commands and constraints:

```bash
cp project/AGENTS.md.template /path/to/repo/AGENTS.md
```

Do not duplicate the global workflow rules in every repository. Keep project instructions short, accurate, and specific.

## Optional config

Merge `config-snippet.toml` into `~/.codex/config.toml` or a trusted project's `.codex/config.toml`. The package does not overwrite config automatically.

The snippet explicitly selects the official Multi-agent V2 runtime, enables the agent runtime and interrupt messages, and sets only the top-level Main `model` and `model_reasoning_effort` defaults. It intentionally leaves subagent default model/effort keys and concurrency unset because every custom role pins its own model/effort and the runtime chooses concurrency.

## Intended workflow

Compose the workflow from only the gates that materially improve the result. Use the full pipeline only for a high-risk change where every gate is justified:

```text
Explorer(s)
  -> Architect
  -> fresh Reviewer (ARCHITECTURE)
  -> Worker packet(s)
  -> Tester
  -> fresh Reviewer (CODE+ACCEPTANCE)
  -> Git Operator only when requested
```

For a small obvious change, the primary thread should implement it directly when it already has the necessary context. Use one `worker` only when isolation, restriction, or model-tier savings outweigh the prompt and handoff overhead. For non-trivial work, add exploration, architecture, independent testing, and review conditionally according to uncertainty, reversibility, public-contract impact, regression risk, and acceptance risk; the full pipeline is not the default.

## Handoff design

Every subagent ends with a compact `## Handoff` block containing status, next role, summary, evidence, decisions, changes, risks, blockers, and one next action. The architect additionally emits bounded implementation packets with explicit write surfaces, invariants, acceptance checks, and escalation conditions.

This is intentionally Markdown rather than a JSON workflow schema. It is human-readable, survives model/version changes, and is sufficient for the primary Codex thread to route the next step.

## Smoke test

The current documented Codex CLI compatibility baseline is **0.147.0**. Local parsing and installer checks are necessary but not sufficient for a release claim: after installation, start a new Codex session in a real repository on the baseline/current CLI and run this end-to-end smoke prompt:

```text
Summarize the active engineering-team routing and handoff rules, then list the available custom agents. Do not edit files.
```

Confirm that the response names the seven canonical custom roles and follows the routing/access rules. Then try one real medium-sized feature using a sample prompt from `sample-prompts.md`; record the CLI version and any runtime permission/concurrency choices rather than assuming the package controls them.
