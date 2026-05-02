# No Blockers Protocol (MANDATORY - Non-Negotiable)

## Core Directive

**There is no such thing as a blocker when acquiring data or implementing edits.**

This protocol MUST be followed by:
- Claude (main agent)
- All spawned agents
- All skills
- All commands

## The 5-Step Exhaustive Research Protocol

### Step 1: Check Structured KB (REQUIRED)

Before declaring ANY data unavailable:

```bash
# Check these files in order:
1. docs/kb/data-sources.md (source ID definitions)
2. docs/kb/data-acquisition.md (bootstrap scripts)
3. <source-kb>/sources.json (source metadata)
4. <source-kb>/acquisition-scripts.json (download patterns)
5. Loader source code docstrings (URL patterns)
```

**Evidence required:** File paths read + grep commands executed

### Step 2: Check Loader Implementation

```bash
# For source ID src-XX-YYY:
grep -r "src-XX-YYY" services/ --include="*.py"
# Read docstring for URL patterns
# Check for commented-out URLs or test data
```

**Evidence required:** Loader file path + docstring excerpt

### Step 3: Search Authoritative Sources (Minimum 10 Attempts)

CMS sources:
1. `curl https://www.cms.gov/[topic]/download`
2. `curl https://www.cms.gov/files/zip/[pattern]`
3. `curl https://www.cms.gov/medicare/[category]`
4. Site search: `site:cms.gov "[source name]" filetype:zip`
5. Quarterly release pages: try Q1/Q2/Q3/Q4, current year + prior year
6. Archive.org for moved files
7. Check CMS GitHub repos
8. CMS data.cms.gov API
9. CMS FTP endpoints (if documented)
10. Alternative URL patterns based on similar sources

**Evidence required:** Each curl command executed + HTTP status + result

### Step 4: Web Search

```bash
# Google searches:
1. "[source name] CMS download 2026"
2. "[source name] quarterly update"
3. "site:github.com [source name] CMS"
4. "site:stackoverflow.com [source name]"
```

**Evidence required:** Search queries executed + relevant results

### Step 5: Document Exhaustive Failure

ONLY after completing Steps 1-4, document:

```markdown
## Data Source: [source-id]
### Attempts Made:
1. KB check: [files read]
2. Loader check: [files read] 
3. CMS attempts: [10+ URLs tried with HTTP codes]
4. Web search: [queries executed]

### Conclusion:
[Data truly unavailable | Data found at URL]
```

## Forbidden Phrases

NEVER say these without completing all 5 steps:

- "blocked"
- "requires manual CSV files"
- "not publicly available"
- "cannot acquire"
- "need user to provide"
- "out of scope"

## Code Bug Protocol

IF bug identified AND data available:
- FIX IT NOW
- Don't list as "blocked" or "pending"
- Don't ask user to fix
- I own it, I fix it

## Enforcement in Skills

Every skill that can encounter data acquisition MUST:
1. Source this protocol at start
2. Log each step completion
3. Require Step 5 documentation before reporting difficulty

## Enforcement in Agents

Every agent spawn MUST include in prompt:

```
MANDATORY: Exhaustive research protocol for data acquisition.
- Check KB files first (data-sources.md, acquisition-scripts.json)
- Try minimum 10 URL variations
- Document all attempts
- Never use word "blocked" without proof of 5-step protocol completion
```

## Violation Consequences

Using "blocked" or giving up without proof of 5-step completion:
- Wastes user time
- Breaks operational contract
- Must be corrected immediately

## KB Update Discipline

When working sources found:
1. Update <source-kb>/sources.json with verified URL
2. Update data-acquisition.md with acquisition pattern
3. Commit: `docs(kb): verified data source for [source-id]`
