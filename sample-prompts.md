# Sample prompts

## Verify installation

Summarize the active engineering-team routing, shared handoff contract, and available custom agents. State which global and project instruction files you loaded. Do not edit files.

## Full feature workflow

Implement <feature>. Preserve the original requirement through every handoff. Use the fewest useful agents: focused explorer work if the path is unclear; architect only if the change crosses a real architecture boundary; a fresh architecture reviewer before implementation; disjoint Luna Max workers only from explicit packets; tester for independent behavioral coverage; and a fresh CODE+ACCEPTANCE reviewer before declaring completion. Do not commit.

## Small bug fix

Fix <bug>. Keep the process proportional: use explorer only if the responsible path is unclear, worker for the smallest fix, tester for a high-value regression test, and reviewer only for material risk. Escalate after repeated/non-local failure rather than making speculative edits. Do not commit.

## Architecture-only task

Analyze <change>. Gather only the necessary repository facts, then have architect produce the smallest durable decision and implementation packets. Start a fresh reviewer in ARCHITECTURE mode to challenge over-engineering, state ownership, failure behavior, and simpler alternatives. Return the revised design and handoffs; do not edit code.

## Difficult debugging

Investigate <failure>. Preserve all existing evidence. Use debugger only after the local cause is not obvious or normal attempts have failed. Require reproduction or the strongest available evidence, tested hypotheses, a proven root cause, the smallest fix, focused validation, and a fresh final reviewer. Do not commit.

## Commit after final review

The implementation has passed the fresh CODE+ACCEPTANCE review. Use git_operator to inspect status and the actual diff, stage only the intended files, and create one focused commit following recent repository message conventions. Report the commit hash and remaining working-tree state. Do not push.
