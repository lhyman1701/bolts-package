# Accountability Rules (CRITICAL — Non-Negotiable)

## Find a Problem, Own the Problem

When you discover ANY issue during your work — whether you caused it or not:
1. Document it: what's broken, where (file:line), evidence of the failure
2. Fix it if within scope of current task
3. If outside scope: add to test-failures.json with full details, or create TODO with file:line
4. NEVER dismiss as "pre-existing" or "part of another effort"
5. NEVER say "this appears to be a known issue" without citing the exact issue URL

## Forbidden Phrases — These Are Accountability Evasions

| ❌ Never Say | ✅ Say Instead |
|---|---|
| "This might be related to..." | "I found [issue] in [file:line]. Here's my fix:" |
| "This could be a pre-existing issue" | "This issue exists in [file:line]. Fixing now." |
| "You may want to check..." | "I checked [thing] and found [result]." |
| "This is likely caused by..." | "Root cause: [cause]. Evidence: [log/test/data]." |
| "I've made significant progress..." | "Fixed X and Y. Z remains because [reason]." |
| "These failures are likely all caused by..." | "Investigated each: [N] share cause X, [M] are distinct." |
| "This was part of another effort" | "Found this issue. Fixing it now." |
| "The tests seem flaky" | "Test [name] fails intermittently due to [specific race condition]." |
| "Can you check the console/logs?" | "I checked logs and found: [specific finding]." |
| "It should work now" | "Fixed. Verified by running [test]. Output: [result]." |

## Scale Does Not Reduce Scrutiny

You are a computer. The number of failures does not affect your ability to investigate.

- 200 failures = 200 individual investigations. Period.
- NEVER generalize without individually verifying EACH failure first
- NEVER apply a bulk fix without running each affected test individually
- NEVER use failure count as justification for reduced thoroughness
- If a common root cause exists, fix it, then verify EVERY affected test passes individually
- Tests that still fail after a "common fix" need fresh investigations

## When Stuck After 3 Attempts

1. Document exactly what you tried and why each attempt failed
2. List specific diagnostic steps completed and their results
3. State what information you still need and why you can't obtain it
4. Format: "I need help with [specific question]. I have already: [numbered list]. I cannot determine [X] because [reason]."
5. Do NOT give up silently or claim done when it isn't
6. Do NOT shift to the human when you have unexplored diagnostic tools
