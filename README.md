# Codex Engineering Team

**Version 2.0.0** — renames the public implementation and test roles to `worker` and `tester`, respectively, and adds safe migration for package-owned v1.2 legacy files. This is a breaking role-name change; the major version makes that contract change explicit.

A deliberately small Codex subagent team optimized for **simple, long-lived, robust, elegant engineering without over-design**.

> Using Claude Code instead? [**claude-engineering-team**](https://github.com/tonyzhoup/claude-engineering-team) is the same team contract, handoff envelope, and packet format ported to Claude Code subagents.

## Team

| Agent | Model / effort | Access | Responsibility |
|---|---|---|---|
| `explorer` | GPT-6 Luna / Main selects effort | read-only | Repository facts, execution paths, ownership, impact |
| `architect` | GPT-6.1 Sol / Main selects effort | read-only | Minimal durable decisions and implementation packets |
| `worker` | GPT-6 Luna / Main selects effort | workspace-write | Bounded production-code implementation |
| `tester` | GPT-6 Luna / Main selects effort | workspace-write | Independent behavioral and acceptance verification; test-only writes |
| `reviewer` | GPT-6.1 Sol / Main selects effort | read-only | Architecture, code, and acceptance gates |
| `debugger` | GPT-6.1 Sol / Main selects effort | workspace-write | Difficult root-cause debugging and minimal fixes |
| `git_operator` | GPT-6 Luna / Main selects effort | workspace-write | Precise repository-state and Git-history operations |

The primary Codex thread is the supervisor. There is no permanent supervisor agent and no workflow database.

All seven custom roles pin their model and leave reasoning effort unpinned. Main sets `reasoning_effort` explicitly for each spawn based on that task's difficulty and the selected model's supported levels. Without an explicit spawn value, Codex can carry forward a previously resolved effort, so omitting the TOML key alone does not make effort task-aware. The supplied config snippet separately sets the static Main supervisor baseline to GPT-6 Astra with `xhigh` reasoning. Runtime selection also chooses concurrency per task/session; this package does not set a fixed concurrency limit.

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

The snippet explicitly selects the official Multi-agent V2 runtime, enables the agent runtime and interrupt messages, and sets only the top-level Main `model` and `model_reasoning_effort` defaults. It leaves subagent default model/effort keys and concurrency unset. Main selects effort when spawning each of the seven specialists.

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

Main selects effort for every specialist spawn from the assigned task's difficulty, ambiguity, scope, risk, and evidence needs. It may choose a different level for the same role on a later task, or adjust the level as a follow-up becomes simpler or harder. The choice must be supported by the selected model and runtime and proportional to its expected benefit in quality, latency, and cost.

Successful workers return to the primary thread, which decides whether remaining risk warrants an additional gate. Sufficiently validated low-risk work can finish without another agent.

For an ordinary behavior-dominant change, `tester` can serve as the acceptance gate and return its evidence directly to the primary thread. It strengthens verification rather than replacing `reviewer`. For an ordinary structural or non-behavioral risk, use `reviewer` instead. Combine them only when the change is high-risk and each gate resolves a distinct material uncertainty.

Tester verdicts use the current code state and unresolved relevant failures. Report earlier failures even after a supported correction and successful revalidation; a passing rerun alone does not resolve possible flakiness. A failed check can be excluded from the verdict only with evidence that it is unrelated to required behavior. Unresolved reproducible behavior defects mean `FAIL`; otherwise, missing evidence or any unresolved relevant failure or material behavioral risk means `INCONCLUSIVE`. `PASS` requires sufficient acceptance evidence, passing final relevant checks, and no unresolved relevant failure or material behavioral risk.

Reviewer is optional for local, readily verified changes. Start fresh for an independent gate, but reuse that reviewer for correction rechecks within the same scope. Repeated failures return to Main for reassessment; Main may diagnose directly or delegate to debugger when the investigation benefit exceeds the handoff cost.

## Handoff design

Every subagent returns a single compact `## Handoff` containing status, next role/action, and role-specific results, evidence, changes, risks, and blockers. Verdicts and architecture packets belong inside that handoff, not in a duplicate report. Default to a fresh context with a minimal complete task packet and artifact references; send only deltas for bounded same-task follow-ups. Delegate by uncertainty, verifiability, and expected whole-task cost. Preserve independent judgment and all material acceptance evidence.

This is intentionally Markdown rather than a JSON workflow schema. It is human-readable, survives model/version changes, and is sufficient for the primary Codex thread to route the next step.

## Smoke test

The current documented Codex CLI compatibility baseline is **0.147.0**. Local parsing and installer checks are necessary but not sufficient for a release claim: after installation, start a new Codex session in a real repository on the baseline/current CLI and run this end-to-end smoke prompt:

```text
Summarize the active engineering-team routing and handoff rules, then list the available custom agents. Do not edit files.
```

Confirm that the response names the seven canonical custom roles and follows the routing/access rules. Then try one real medium-sized feature using a sample prompt from `sample-prompts.md`; record the CLI version and any runtime permission/concurrency choices rather than assuming the package controls them.

### Context transfer budgets

Always pass `fork_turns="none"` explicitly for routine delegation: omitting it inherits full history. Justified recent-history forks normally use 1-2 turns; summarize large logs instead. Initial packets target <= 1,500 tokens, follow-up deltas <= 500, ordinary handoffs <= 1,000, and complex design/review handoffs <= 2,000. Preserve essential evidence and explain necessary overruns. These are soft writing targets, not runtime-enforced caps or cumulative usage limits.

Search first and read bounded excerpts; usually request 2,000-4,000 tokens per tool output. Simple handoffs retain status and required verdicts but may omit empty headings. Main checks decisive evidence without repeating the whole investigation. Static tests protect these documented rules; they do not enforce live message sizes. Evaluate savings using combined parent/child usage, cached input, output, elapsed time, and rework when available; no savings percentage is assumed.
