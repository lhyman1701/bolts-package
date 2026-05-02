# Completion Contract Rule (MANDATORY)

## The Problem

On 2026-04-30, I claimed "validate all domain-specific edits loaders 100%" but only validated 5 of 16 loaders. This nearly shipped incomplete work to production.

**Root cause:** No explicit completion criteria before starting work. I made implicit "obviously not critical" shortcuts.

## The Rule

Before claiming "done", "complete", "100%", "validated all", or similar:

### 1. Write Completion Contract

Create `/tmp/completion-contract-{work-id}.md` with:
- **ALL items** to complete (explicit list, no "etc", no ranges, no "critical subset")
- **DONE criteria** for each (row counts, API responses, test output - not "works")
- **Verification method** for each (SQL query, API call, test command)
- **Out of scope** items (explicitly state what's NOT included and why)

### 2. Get User Approval

- Show contract to user
- Wait for explicit "approved" response
- Do NOT proceed until approved

### 3. Execute Against Contract ONLY

- Work ONLY on contract items
- No additions
- No implicit "this isn't needed" shortcuts
- No "obviously the ACs don't require this" reasoning

### 4. Verify at Completion

Before claiming done:
- Check: ALL contract items marked ✅
- Check: Planned items == Completed items (diff must be empty)
- Capture evidence for each item
- Run: `verify_completion_contract /tmp/completion-contract-{work-id}.md`

## Applies To

- Direct work by me
- All skills I invoke (/work, /run-bolt, /test, /deploy, /audit-deep, etc.)
- All agents I spawn
- All sub-agents they spawn
- **ESPECIALLY Linear tickets** - ACs are high-level, must expand to concrete checklist

## Implementation

Source the protocol at start of any completion work:

```bash
source .claude/shared/validation-protocol.sh
enforce_completion_contract "$WORK_ID"
```

Skills that MUST use this:
- `/work` - implements Linear tickets
- `/run-bolt` - processes epics
- `/test` - runs test suites
- `/deploy` - deploys to environments
- `/audit-deep` - validates compliance
- `/investigate-failures` - debugs issues
- Any skill with "validate", "complete", "all", "100%" in usage

## Violation Consequence

User wastes time catching my incomplete work. Trust is broken. Effort is ruined.

## See Also

- `.claude/shared/validation-protocol.sh` - enforcement functions
- `.claude/hooks/skill-pre-exec.sh` - automatic enforcement
- `memory/feedback_completion_contracts.md` - memory for all sessions
