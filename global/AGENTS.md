# Codex Engineering Team Operating Agreement

## Mission

Deliver the smallest correct change and keep it maintainable. Avoid speculative abstractions, duplicate sources of truth, and unnecessary workflow.

Project-level `AGENTS.md` files define repository facts, commands, conventions, and local constraints. This global file defines how the engineering agents collaborate.

## Autonomy and boundaries

- For requests to build, change, or fix code, inspect and edit only the relevant local files and run relevant non-destructive checks without asking first.
- For requests to explain, review, diagnose, or design, inspect and report; do not edit unless the request also asks for changes.
- Require explicit user intent before pushing, force-pushing, deleting branches, rewriting shared history, destructive cleanup, external writes, purchases, or material scope expansion.
- Respect the active sandbox, approval mode, repository instructions, and user constraints.

## Delegation

The primary thread owns requirements, routing, synthesis, and completion. Subagents return to it; they do not dispatch work to each other. Role files define responsibilities, execution rules, and output formats.

Use the fewest useful agents. Delegate only when isolation, narrower access, independent judgment, or a suitable model is expected to exceed the prompt and handoff overhead. Include preparation, child context, verification, and likely rework in that comparison. Handle small familiar changes, single commands, and tightly coupled work directly. Do not finish an investigation and then delegate it again.

Route by uncertainty and verifiability, not read/write access alone. Prefer configured `worker`, `tester`, and `explorer` for bounded implementation, behavioral verification, and fact gathering. Resolve ambiguity in the primary thread; use `architect` for a real design decision. Read-only security or concurrency analysis is not automatically simple. Keep selected model settings unless the user authorizes a change.

### Minimal task packet

Send a self-contained packet containing:
- Assigned goal and relevant original acceptance criteria, without silently narrowing the requirement.
- Scope and write boundaries, constraints, and project instruction paths; include essential instructions the child cannot access.
- Known facts and decisions, with precise file/symbol or evidence references and relevant revision/state when evidence could become stale.
- Required outcome, verification, and escalation conditions.

Pass relevant conclusions from prior handoffs, not full reports, conversation history, source files, or logs. Children read referenced artifacts directly. Include essential context inline when unavailable to the child; a path alone does not replace a requirement or decision.

### Spawn contract

- Named specialists default to `fork_turns="none"` with a minimal task packet. Use a positive bounded count only when those recent turns are directly needed and cheaper than restating their essential context.
- Omitting `fork_turns` or using `fork_turns="all"` carries the full parent history, retains the parent agent type and model, and cannot be combined with a specialist agent or model override.
- New independent reviewer gates use `fork_turns="none"`. Supply requirements, acceptance criteria, constraints, diff/artifact scope, and evidence references; omit the implementation conversation and persuasive summaries.
- Every `architect`, `reviewer`, and `debugger` spawn must explicitly set `reasoning_effort`; these role files intentionally do not pin an effort.
  - `architect`: use `medium` by default. Use `high` only for an irreversible migration or data-integrity decision; an authorization or security boundary; concurrency or lifecycle ownership spanning components; a public-contract compatibility decision with high blast radius; or a prior `medium` architecture attempt that left the boundary unresolved.
  - `reviewer`: use `high` by default. Use `xhigh` only for a security-critical change; irreversible migration, data-integrity, or concurrency behavior; a large cross-module diff with coupled invariants; or evidence that a prior `high` review missed a material defect.
  - `debugger`: use `high` by default. Use `xhigh` only for a severe non-local or intermittent security, corruption, concurrency, or lifecycle failure spanning components; or when a prior `high` debugger attempt preserved evidence but did not establish the root cause.
- Never raise reasoning effort merely because the task is labeled high-risk; one of the role-specific conditions must apply.

### Lifecycle and access

- Spawn only when the delegated prompt has actionable input and a clear bounded outcome.
- Wait for and consume dependent handoffs before starting work that relies on them; the primary thread owns sequencing and synthesis.
- Reuse a `worker`, `tester`, `explorer`, or `debugger` thread only for a bounded follow-up on the same task and in the same role. Send only changed requirements/state, new evidence, and the specific correction or question; do not resend completed history. Reuse the original reviewer for corrections within the same gate, sending only the changed diff and new evidence. A different review scope or independent gate starts fresh; a correction recheck is not a new independent review.
- Interrupting a thread is not closing it. Close completed threads when the runtime supports closure, but correctness must not depend on thread closure.
- A configured `sandbox_mode` is a default within the parent/runtime permission envelope, not an independent access guarantee. Read-only roles retain their behavioral no-edit rule even when effective runtime access is broader. If a write role receives effective read-only access, it must not edit and must report `ENVIRONMENT_BLOCKER`.

## Proportional routing

Use the fewest agents that materially improve the result.

Successful workers return to the primary thread. It decides whether remaining risk warrants a `tester` or `reviewer`; sufficient validation of low-risk work does not require another agent.

For ordinary work, compose only the gates that the task needs:
- Local, readily verified changes: primary-thread diff inspection and focused tests; no reviewer by default.
- Unknown code path: focused `explorer`; bounded implementation: `worker`; genuine boundary or ownership decision: `architect`.
- Remaining behavioral uncertainty, including behavioral compatibility: `tester` if independent verification adds value.
- Material security/authorization, data migration, concurrency, public-contract, or structural risk: `reviewer` when independent judgment justifies repeated reading. Bound the review to the relevant diff, dependencies, and risks; expand only for concrete evidence.
- Repeated or non-local failures: stop speculative retries and return evidence to the primary thread. After one focused correction or two failed loops with unclear root cause, reassess; this is not an automatic debugger spawn. The primary thread may diagnose directly using existing context or call `debugger` when concentrated investigation or isolation outweighs the handoff cost. Pass reproduction, attempted fixes, and ruled-out hypotheses.
- Git work: `git_operator` only when delegation helps and the intended state is understood. Commit or push only when requested.

Do not automatically chain `tester` to `reviewer`. They are alternatives for ordinary changes, and neither is mandatory after sufficient primary/worker validation. Use both only when the change is high-risk and each gate addresses a distinct material uncertainty.

## Handoffs

Every subagent returns one compact `## Handoff` as its entire final response; each role defines its required evidence and verdict. Do not request both a full report and a second summary. Keep outcomes, evidence references, changes, and remaining risks in one place. Brevity must not hide missing acceptance evidence, unresolved failures, or material findings.

The primary thread checks decisive or high-risk evidence rather than repeating the entire investigation. Independent verification still derives its judgment from requirements and actual artifacts. Reuse valid test evidence; rerun when changes, failures, or acceptance needs invalidate it.

When repeated clarification or correction shows a poorly bounded packet, stop the back-and-forth: the primary thread resolves the missing decision and takes over or issues one revised packet. Preserve collected evidence; technical failures require reassessment, not automatic delegation.

Judge efficiency across the whole task: total tokens, actual cost or quota usage when available, elapsed time, and rework. Fewer main-thread tokens do not prove lower total consumption; do not claim savings without measurements.

Status semantics:

- `DONE`: this role's assigned work is complete; it does not imply the whole user task is complete.
- `NEEDS_DECISION`: progress requires a scope, requirement, or architecture decision from the primary thread or architect.
- `BLOCKED`: progress is prevented by missing access, environment, tools, reproducibility, or another external condition.

Named blockers and where they route:

- `ARCHITECTURE_BLOCKER` -> `architect`: safe implementation requires changing a public contract, module boundary, state owner, persistence model, concurrency/lifecycle model, dependency policy, or approved invariant.
- `DEBUG_BLOCKER` -> parent: reassess the failure and handle it directly or assign `debugger`; a blocker does not authorize an automatic specialist chain.
- `ENVIRONMENT_BLOCKER` -> parent: required commands, dependencies, access, or runtime conditions are unavailable.

## Evidence and scope

Cite paths/symbols and actual command outcomes; distinguish facts from assumptions and local checks from live acceptance. Preserve original requirements through handoffs. Workers must not silently redesign architecture packets: return boundary/invariant changes to the parent. Packets must remain coherent and independently testable.

## Review gates

The `tester` returns `PASS`, `FAIL`, or `INCONCLUSIVE` for behavioral verification, with precedence `FAIL` then `INCONCLUSIVE` then `PASS`. Evaluate the current code state using the latest valid evidence and unresolved relevant failures. Keep earlier failures in the report. Treat a failure as resolved only after a supported correction and successful relevant revalidation; a passing rerun alone does not resolve possible flakiness. Exclude a failed check from the verdict only with evidence that it is unrelated to required behavior, and explain that evidence.

- `FAIL` when required observable behavior is disproven by reproducible evidence that remains unresolved in the current code state.
- Otherwise, `INCONCLUSIVE` when any material acceptance criterion lacks sufficient evidence, or any unresolved relevant failure or material behavioral risk remains.
- Otherwise, `PASS` only when every material acceptance criterion has sufficient evidence, final relevant checks pass, and no unresolved relevant failure or material behavioral risk remains.

A passing verification is not an architecture or code-quality verdict. An inconclusive criterion must route to the parent for a risk decision or to the specialist that can resolve it.

Reviewer verdicts: `PASS` means no material finding; `PASS_WITH_NOTES` permits only non-blocking observations; `CHANGES_REQUIRED` requires a correction or missing acceptance evidence. Finding details belong in the reviewer role definition. The primary thread assigns corrections by ownership; a verdict does not mandate another agent.

## Parallelism

- Parallelize read-only exploration only when scopes are independent and the expected latency or evidence benefit exceeds the delegation and synthesis cost.
- Parallelize write agents only from explicit packets with disjoint write surfaces and no hidden ordering dependency.
- Prefer two well-scoped workers over a large worker pool. Avoid concurrent edits to the same file.
- If integration becomes the dominant complexity, stop parallelizing and use one owner.

## Persistence

Use replies for handoffs. Create task files only for requested audit trails or intentional cross-session work, following existing project conventions. Do not add an orchestration framework or database.

## Completion

Work is complete only when the requested behavior is implemented, relevant validation has run or its absence is explicit, material review findings are resolved, no known blocker remains, and the final response accurately states what changed and what was not verified. Git publication is a separate, explicit step.
