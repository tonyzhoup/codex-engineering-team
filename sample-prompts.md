# Sample prompts

## Verify installation

Summarize the active engineering-team routing, shared handoff contract, available custom agents, and how Main selects reasoning effort for each specialist spawn. State which global and project instruction files you loaded. Do not edit files.

## Full feature workflow

Implement <feature>. Preserve the original requirement through every handoff. Use the fewest useful agents: focused explorer work if the path is unclear; architect only if the change crosses a real architecture boundary; disjoint workers only from explicit packets; tester as the acceptance gate for observable behavior; and reviewer only for material non-behavioral risk. Select `reasoning_effort` explicitly for each specialist spawn from that subtask's complexity and the selected model's supported levels. Do not automatically chain tester to reviewer; use both only when the change is high-risk and they resolve distinct material uncertainties. Do not commit.

## Small bug fix

Fix <bug>. Keep the process proportional: handle a small obvious fix in the primary thread; use explorer only if the responsible path is unclear and worker only when delegation is worthwhile. Successful workers return to the primary thread; add tester only for remaining behavioral verification needs or reviewer only for material structural risk. Sufficiently validated low-risk work can finish without another agent. Escalate after repeated/non-local failure rather than making speculative edits. Do not commit.

## Architecture-only task

Analyze <change>. Gather only the necessary repository facts, then have architect produce the smallest durable decision and implementation packets. Start a fresh reviewer in ARCHITECTURE mode to challenge over-engineering, state ownership, failure behavior, and simpler alternatives. Return the revised design and handoffs; do not edit code.

## Difficult debugging

Investigate <failure>. Preserve all existing evidence. Use debugger only after the local cause is not obvious or normal attempts have failed. Require reproduction or the strongest available evidence, tested hypotheses, a proven root cause, the smallest fix, and focused validation. Route the result to tester for behavioral/regression verification or reviewer for material structural risk; use both only when the change is high-risk and they resolve distinct material uncertainties. Do not commit.

## Commit after final review

The implementation has passed the fresh CODE+ACCEPTANCE review. Use git_operator to inspect status and the actual diff, stage only the intended files, and create one focused commit following recent repository message conventions. Report the commit hash and remaining working-tree state. Do not push.
