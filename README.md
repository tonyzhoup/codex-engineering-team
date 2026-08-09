# Codex Engineering Team

**Version 1.2** — adds a real global operating agreement and explicit handoff/input/output contracts for all seven agents.

A deliberately small Codex subagent team optimized for **simple, long-lived, robust, elegant engineering without over-design**.

## Team

| Agent | Model / effort | Access | Responsibility |
|---|---|---|---|
| `explorer` | GPT-5.6 Terra / high | read-only | Repository facts, execution paths, ownership, impact |
| `architect` | GPT-5.6 Sol / xhigh | read-only | Minimal durable decisions and implementation packets |
| `implementer` | GPT-5.6 Luna / max | workspace-write | Bounded production-code implementation |
| `test_engineer` | GPT-5.6 Luna / max | workspace-write | Independent requirement-driven tests |
| `reviewer` | GPT-5.6 Sol / xhigh | read-only | Architecture, code, and acceptance gates |
| `debugger` | GPT-5.6 Sol / xhigh | workspace-write | Difficult root-cause debugging and minimal fixes |
| `git_operator` | GPT-5.6 Luna / high | workspace-write | Precise repository-state and Git-history operations |

The primary Codex thread is the supervisor. There is no permanent supervisor agent and no workflow database.

## Where the contracts live

```text
~/.codex/
├── AGENTS.md          # team routing, shared handoff envelope, gates, escalation
├── agents/            # each role's authority, expected input, and required output
│   └── *.toml
└── config.toml        # multi-agent runtime settings

<repo>/
└── AGENTS.md          # repo layout, commands, conventions, constraints, done criteria
```

The global file says **how the team collaborates**. Each TOML says **how that role works**. A repository `AGENTS.md` says **how this codebase works**.

Handoffs remain in the subagent response by default. Do not create per-task files unless you intentionally need cross-session persistence or an audit trail.

## Install

From this directory:

```bash
./install-user.sh
```

The installer:

1. installs the seven TOML files, backing up only changed same-named files under `${CODEX_HOME:-~/.codex}/agents/`;
2. appends or replaces one clearly marked block in global `AGENTS.md`, backing it up only when content changes;
3. leaves `config.toml` untouched and tells you how to merge the supplied snippet.

Run only the agent-file installation with:

```bash
./install-user.sh --agents-only
```

If a non-empty `~/.codex/AGENTS.override.md` exists, Codex uses it instead of the global `AGENTS.md`; the installer warns rather than changing the override.

## Add project facts

Copy the template into a repository and fill it with actual commands and constraints:

```bash
cp project/AGENTS.md.template /path/to/repo/AGENTS.md
```

Do not duplicate the global workflow rules in every repository. Keep project instructions short, accurate, and specific.

## Optional config

Merge `config-snippet.toml` into `~/.codex/config.toml` or a trusted project's `.codex/config.toml`. The package does not overwrite config automatically.

## Intended workflow

For a non-trivial change:

```text
Explorer(s)
  -> Architect
  -> fresh Reviewer (ARCHITECTURE)
  -> Implementer packet(s)
  -> Test Engineer
  -> fresh Reviewer (CODE+ACCEPTANCE)
  -> Git Operator only when requested
```

For a small obvious change, skip architecture and use only the minimum useful roles.

## Handoff design

Every subagent ends with a compact `## Handoff` block containing status, next role, summary, evidence, decisions, changes, risks, blockers, and one next action. The architect additionally emits bounded implementation packets with explicit write surfaces, invariants, acceptance checks, and escalation conditions.

This is intentionally Markdown rather than a JSON workflow schema. It is human-readable, survives model/version changes, and is sufficient for the primary Codex thread to route the next step.

## Smoke test

After installation, start a new Codex session in a real repository and ask:

```text
Summarize the active engineering-team routing and handoff rules, then list the available custom agents. Do not edit files.
```

Then try one real medium-sized feature using a sample prompt from `sample-prompts.md`.
