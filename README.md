# bolts-package

**A complete build specification.** This repo tells a future Claude Code session how to build two slash-command skills — `/make-bolt` and `/run-bolt` — inside a target project. It does not contain runnable code. It contains the spec, the prompts, the configs, the rules, and the installer that copies all of those into the target project's `.claude/` directory.

After the installer runs, a Claude Code session in the target project reads the kickoff prompt and builds the two skills over ~6-8 weeks of milestones (M0 through M5-pilot+1).

---

## What you (or a future Claude) get from this repo

Two slash commands, built into a target project's `.claude/skills/`:

### `/make-bolt <requirements>` — Epic + ticket factory
Takes requirements in any form (free text, PDFs, screenshots, URLs, YAML), researches the domain, decomposes into tickets, validates a DAG, gates writes behind a human-approved diff, and writes the epic to a ticket tool (Azure DevOps Work Items / Jira / GitHub Issues / repo-local markdown). Three modes: CREATE, MODIFY, REVERIFY.

### `/run-bolt <epic-key>` — Autonomous epic executor
Picks DAG-ready tickets in waves of 4-8, spawns Claude sub-agents in isolated git worktrees, runs unit + integration + E2E + accessibility + mutation + security gates, runs three mandatory AI reviewers (code + security + HIPAA) in parallel, opens PRs in Azure Repos, polls Azure Pipelines, auto-merges only if all gates pass, watches for regressions post-merge, reopens superseded tickets, and writes a complete audit trail to an orphan git branch.

Both skills maintain a **codebase knowledge graph** (DuckDB + Tree-sitter + optional Roslyn fusion) updated on every run, and **self-improve** via a two-tier system (low-risk auto-apply, high-risk PR proposals).

---

## Diagram 1 — How this repo gets used (lifecycle)

```mermaid
flowchart LR
    A[bolts-package repo<br/>spec only] -->|Step 1<br/>install.sh| B[target project<br/>.claude/]
    B -->|Step 2<br/>git commit| C[target project<br/>committed spec]
    C -->|Step 3<br/>paste kickoff prompt| D[Claude Code<br/>reads spec]
    D -->|writes read-back| E[human acks<br/>read-back]
    E -->|answers 9 open Qs| F[M0 → M5-pilot+1<br/>~6-8 weeks]
    F -->|writes code into| G[target project<br/>.claude/skills/make-bolt/<br/>.claude/skills/run-bolt/]
    G -->|now usable| H[/make-bolt &amp; /run-bolt<br/>fully functional/]

    style A fill:#e8f0ff,stroke:#3060a0
    style G fill:#e8ffe8,stroke:#308030
    style H fill:#e8ffe8,stroke:#308030,stroke-width:2px
```

---

## Capability matrix (one-glance overview)

| Capability | `/make-bolt` | `/run-bolt` |
|---|:---:|:---:|
| Accepts free text, PDFs, screenshots, URLs, YAML | ✓ | — |
| Researches domain via internal KB + web | ✓ | (via sub-agents) |
| Decomposes requirements into HQC-compliant tickets | ✓ | — |
| Validates DAG (no cycles, no scope-overlap) | ✓ | ✓ |
| Diff-gated writes (no Linear/ADO write before human approval) | ✓ | — |
| Writes to ticket tool (ADO / Jira / GitHub / markdown stub) | ✓ | (state updates only) |
| CREATE mode (new epic) | ✓ | — |
| MODIFY mode (augment existing, Backlog only) | ✓ | — |
| REVERIFY mode (read-only audit) | ✓ | — |
| Picks DAG-ready tickets in waves of 4-8 | — | ✓ |
| Spawns Claude sub-agents in isolated git worktrees | — | ✓ |
| Runs unit + integration + E2E + a11y + mutation + security gates | — | ✓ |
| 3 mandatory AI reviewers (code + security + HIPAA) on every PR | — | ✓ |
| Opens PRs in Azure Repos, polls Azure Pipelines, auto-merges | — | ✓ |
| Reopens tickets on regression / KB-break / supersession | — | ✓ |
| Brown-field adoption (P0.5) — retroactive grading of Done tickets | — | ✓ |
| Circuit breaker (3 consecutive quality-gate failures → pause) | — | ✓ |
| Halt-Quality Contract enforcement (every halt validated) | ✓ | ✓ |
| **Standards-Coherence Bridge** — every ticket validated against run-bolt's full semantic standards (HIPAA AC-compliance, KG-aware scope, mutation-feasibility, mandatory-test-type policy, Dafny-invariant exposure, HIPAA reviewer pre-flight) | ✓ | ✓ |
| Codebase knowledge graph (DuckDB + Tree-sitter + Roslyn fusion) | reads | reads + writes |
| App-type detection (HIPAA / PCI / FERPA / FDA-SaMD / AI / PII) | (one-time at M0) | (verified each run) |
| Self-improvement (L0 auto-apply, L1+ PR proposals) | (drift signals checked) | (drift signals checked) |
| Audit trail to orphan git branch (`bolt/audit/<epic>`) | — | ✓ |
| Mock-mode + shadow-mode for first-run hardening | — | ✓ |

---

## Diagram 2 — `/make-bolt` six-phase pipeline

```mermaid
flowchart TD
    Start([User invokes<br/>/make-bolt &lt;requirements&gt;]) --> Mode{Mode<br/>detection}

    Mode -->|first arg matches EP-...<br/>+ --reverify| RV[REVERIFY<br/>read-only audit]
    Mode -->|first arg matches EP-...| Mod[MODIFY<br/>augment existing epic]
    Mode -->|otherwise| Cre[CREATE<br/>new epic]

    RV --> RVOut[/markdown report<br/>plans/...-reverify.md/]
    RVOut --> RVDone([exit])

    Cre --> P1
    Mod --> P1

    P1[P1 INGEST<br/>parse text, PDFs, screenshots,<br/>URLs, YAML → unified.md] --> P2
    P2[P2 RESEARCH<br/>sub-agent reads KB + web<br/>→ research-brief.md] --> P3
    P3[P3 DECOMPOSE<br/>sub-agent emits ticket-candidates.json<br/>with ACs, scope, DoD, dependencies] --> P4
    P4{P4 STRUCTURAL-VALIDATE<br/>HQC + DAG + REG-1..6 +<br/>migration-serial + measurable-AC}

    P4 -->|blocking failure| Halt([halt with<br/>specific halt-code])
    P4 -->|all pass| P45

    P45{P4.5 STANDARDS-BRIDGE<br/>shared validator — same one run-bolt calls<br/>1. structural HQC re-run<br/>2. app-type AC compliance HIPAA/PCI/FDA<br/>3. KG-aware scope correctness ≥ 0.7 coverage<br/>4. mutation- and coverage-feasibility<br/>5. mandatory-test-type policy<br/>6. Dafny-invariant exposure<br/>7. reopen-c self-audit<br/>8. HIPAA-reviewer pre-flight HIPAA mode}

    P45 -->|blocking failure| HaltSB([halt with<br/>same halt-code run-bolt would raise<br/>e.g. ac_violates_app_type_standard])
    P45 -->|all pass| P5

    P5[P5 DIFF<br/>generate human-readable diff<br/>plans/...-diff.md] --> Approve{Human types<br/>'approve'?}

    Approve -->|cancel| Cancel([abort])
    Approve -->|approve| P6

    P6[P6 WRITE<br/>idempotent ticket creation via<br/>label-keyed search; never modifies<br/>In-Progress or Done tickets] --> Out[/Tickets in ticket tool<br/>+ scaffolding files committed/]
    Out --> Done([epic ready for /run-bolt])

    style P45 fill:#e8e0ff,stroke:#5040a0,stroke-width:2px
    style P5 fill:#fff8e0,stroke:#a06000
    style Approve fill:#fff8e0,stroke:#a06000,stroke-width:2px
    style Halt fill:#ffe0e0,stroke:#a03030
    style HaltSB fill:#ffe0e0,stroke:#a03030
    style Cancel fill:#ffe0e0,stroke:#a03030
    style Done fill:#e8ffe8,stroke:#308030,stroke-width:2px
```

> **Why P4.5 matters:** make-bolt and run-bolt share a single validator (`bolt_shared/standards_bridge.py`). Run-bolt calls the same function at P0.5 EPIC-INIT and on every sub-agent preflight. A ticket that passes P4.5 cannot fail run-bolt's structural / scope / app-type / policy / Dafny-invariant gates at runtime — those are pre-cleared. Master plan §29 is the spec.

---

## Diagram 3 — `/run-bolt` orchestration (phases + wave loop + reopen engine)

```mermaid
flowchart TD
    Start([User invokes<br/>/run-bolt &lt;epic-key&gt;]) --> Pn1

    Pn1[P-1 MCP-BOOTSTRAP<br/>verify context7, mcp_memory,<br/>filesystem, ADO, Jira MCPs] --> Pn0
    Pn0[P0 CONFIG-VALIDATE<br/>load + schema-check<br/>bolt.config.yaml] --> Pat
    Pat[P0 APP-TYPE-DETECT<br/>classify repo<br/>→ HIPAA / PCI / FERPA / etc.] --> Pkg
    Pkg[P0.25 KG-INIT<br/>Tree-sitter + Roslyn fusion<br/>→ DuckDB graph + calibrated confidence] --> Pei
    Pei[P0.5 EPIC-INIT<br/>build graph, gap detection,<br/>path-claims signoff] --> Pad
    Pad{P0.75 ADOPT<br/>brown-field?}

    Pad -->|green-field| Wave
    Pad -->|brown-field| AdoptGrade[retroactive grading<br/>of Done tickets<br/>→ adoption-report.md]
    AdoptGrade -->|user accepts| Wave

    Wave[Wave loop start]
    Wave --> P1[P1 WAVE-PLAN<br/>lease reclaim, DAG-ready,<br/>gate-first, partition by<br/>path-overlap + scope]
    P1 --> P2[P2 FAN-OUT<br/>4-8 sub-agents in parallel<br/>each in isolation=worktree<br/>with frozen prompt template]

    P2 --> Sub1[sub-agent 1<br/>preflight → research → TDD<br/>→ test → KB-sync → commit]
    P2 --> Sub2[sub-agent 2<br/>same 9-phase loop]
    P2 --> SubN[... up to N]

    Sub1 --> P3
    Sub2 --> P3
    SubN --> P3

    P3[P3 MERGE-WAVE<br/>serial merge by priority + phase<br/>pre-push smoke, KB-sync workflows A/B/C/D,<br/>mutation gate, validators]
    P3 --> AIRev[P3.5 AI REVIEW<br/>code-reviewer + security-reviewer +<br/>HIPAA-reviewer in parallel<br/>cross-family ensemble]

    AIRev -->|any 'block' verdict| Halt([halt PR<br/>ai_reviewer_block])
    AIRev -->|all approve| OpenPR[open PR in Azure Repos<br/>poll Azure Pipelines<br/>auto-merge --squash]

    OpenPR --> PostMerge[post-merge:<br/>incremental regression check<br/>git_notes attribution write]
    PostMerge --> Reopen{reopen<br/>candidates?}

    Reopen -->|trigger a-e| ReopenAct[reopen ticket<br/>flip to In Progress<br/>insert next wave with priority boost]
    Reopen -->|none| MoreWaves{DAG<br/>empty?}

    ReopenAct --> MoreWaves

    MoreWaves -->|no| Wave
    MoreWaves -->|yes| P4

    P4[P4 EPIC-CLOSE<br/>final regression, REG-1..6 execution,<br/>final reopen sweep, summary.md]
    P4 --> P5si[P5 SELF-IMPROVE-CHECK<br/>every Nth run only<br/>fetch drift signals → L0 auto-apply<br/>or L1+ PR]
    P5si --> Done([epic complete<br/>audit branch contains<br/>complete evidence chain])

    Halt -.->|breaker counts| CB{Circuit breaker<br/>3 consecutive<br/>quality-gate fails?}
    CB -->|yes| Pause([EPIC_PAUSED_<br/>CIRCUIT_BREAKER<br/>requires --confirm-paused])
    CB -->|no| Wave

    style Wave fill:#e8f0ff,stroke:#3060a0
    style P3 fill:#fff8e0,stroke:#a06000
    style AIRev fill:#fff8e0,stroke:#a06000,stroke-width:2px
    style Reopen fill:#ffe8d0,stroke:#a05000
    style Halt fill:#ffe0e0,stroke:#a03030
    style Pause fill:#ffe0e0,stroke:#a03030
    style Done fill:#e8ffe8,stroke:#308030,stroke-width:2px
```

### Reopen-engine triggers (5)

| Trigger | Source | Detection |
|---|---|---|
| **(a) Regression-attribution** | post-merge incremental tests | new failure → `git blame` test + sources → rank by recency × scope-overlap → reopen if Done & confidence ≥ 0.6 |
| **(b) KB-break** | KB validator failure | `json_path` → provenance → atom_id → `git blame` → ticket |
| **(c) Mandatory test type** | policy effective_date passed | every Done ticket whose merged_at < effective_date AND missing required test type |
| **(d) Supersession** | new ADR with `supersedes:` frontmatter | look up ticket via `kb_currency_deps` |
| **(e) Standards-sweep** | manual `--reopen-only --trigger e` | full re-eval against current `policy.yaml` |

Storm protection: `policy.max_reopens_per_run = 5`, `policy.max_reopens_per_ticket = 2`. Beyond budget → halt `reopen_budget_exceeded`.

---

## Who this is for

You are running Claude Code (Opus 4.7 with 1M context, recommended). You have a project that:
- Is **.NET (C#) backend + Angular or React frontend**
- Hosts on **Azure** (App Service / AKS / Container Apps)
- Uses **Azure Repos + Azure Pipelines**
- Handles **PHI in production** (full HIPAA mode)

If your project doesn't match all four, the master plan §2 lists which decisions are negotiable; you'll need to fork the spec and adjust.

---

## What "build" means here — there is no runtime in this repo

The skills don't exist yet. Cloning this repo gives you a *spec*, not a *binary*. After installation, you open Claude Code in the target project, paste the kickoff prompt, and Claude builds the skills (~6-8 weeks of work across 17 milestones) by reading the spec and writing code into the target project. Once built, the skills live in the target project's `.claude/skills/make-bolt/` and `.claude/skills/run-bolt/`.

This repo is the **build spec**, not the **build artifact**.

---

## Three-step quickstart

### Step 1 — Install the spec into your target project

```bash
# Clone this repo somewhere (NOT inside your target project):
git clone --branch v1.1.0 https://github.com/lhyman1701/bolts-package.git /tmp/bolts-package

# Run the installer, pointing it at your target project's repo root:
/tmp/bolts-package/install.sh /path/to/your/target/project

# The installer copies plans, rules, protocols, and the abstract reference into
# /path/to/your/target/project/.claude/. It is idempotent — safe to re-run.
```

The installer verifies a SHA-256 manifest before and after copying. If integrity fails at either end, it halts.

### Step 2 — Commit the spec into the target project

```bash
cd /path/to/your/target/project
git add .claude/ .gitignore
git commit -m "chore: install bolts-package v1.1.0 (plan rev 2026-05-02)"
```

### Step 3 — Open Claude Code and paste the kickoff prompt

```bash
cd /path/to/your/target/project
claude
```

Inside the Claude Code session:

```
/model           # select opus[1m] (Opus 4.7 with 1M context)
/plan            # enter plan mode
```

Then open `.claude/plans/2026-05-02-make-bolt-KICKOFF-PROMPT.md`. Find the section that begins with `## Prompt`. Copy the **entire** code block under that heading — exactly as written, no paraphrasing, no summarization — and paste it into the Claude Code chat.

Claude will:
1. Read the master plan + research files (~6,000 lines of spec).
2. Write a one-page understanding to `.claude/plans/2026-05-02-make-bolt-readback.md`.
3. **Halt** for your acknowledgment of the read-back.
4. Once you say "proceed", surface 9 open questions (ticket tool selection, embeddings vendor, CI check names, etc.).
5. Once you answer, start at milestone M0.

After M0 closes, the skills `/make-bolt` and `/run-bolt` start to exist. They become fully functional at M5. The full milestone list is in the master plan §18.

---

## What's in this repo (every file accounted for)

```
bolts-package/
├── README.md                               ← you are reading this
├── install.sh                              ← idempotent installer; verifies manifest
├── .gitignore                              ← keeps __pycache__, .DS_Store out
│
├── plans/                                  ← the build spec (Claude reads these to build the skills)
│   ├── MANIFEST.sha256                     ← integrity checksums for all files in plans/
│   ├── 2026-05-02-make-bolt-run-bolt-port-spec.md
│   │   └── MASTER PLAN — 28 sections, 1,319 lines, single source of truth
│   ├── 2026-05-02-make-bolt-KICKOFF-PROMPT.md
│   │   └── The exact prompt to paste into Claude Code (Step 3 above)
│   ├── 2026-05-02-make-bolt-kg-research.md
│   │   └── Knowledge-graph subsystem research (Tree-sitter, DuckDB, gates, embeddings)
│   ├── 2026-05-02-make-bolt-hipaa-research.md
│   │   └── HIPAA + AI-review + self-improvement + app-type detection research
│   ├── 2026-05-02-make-bolt-perfection-research.md
│   │   └── Accuracy + first-run defect-rate ceilings (~80 citations)
│   ├── bolt.config.yaml.example
│   │   └── Stub config the skills read at runtime — fill at M0
│   └── .mcp.json.example
│       └── Stub MCP server registry — context7, mcp__memory__, filesystem, azure_devops, jira
│
├── reference/
│   └── SOURCE-SKILL-MECHANICS.md           ← abstracted patterns from the source skills
│       └── Phase order, halt-quality contract, idempotency, KB-sync, reopen engine,
│           manifest schema, quality gates, auto-resolve ladders, circuit breaker.
│           No verbatim source code; no project-specific identifiers.
│
├── rules/                                  ← anti-laziness / accountability contracts
│   ├── accountability.md                   ← forbidden phrases; "find a problem, own it"
│   ├── completion-contracts.md             ← explicit DONE criteria before any "done" claim
│   ├── diagnostics.md                      ← diagnostic-first protocol per failure type
│   └── plans-isolation.md                  ← plans live in repo, never global
│
└── protocols/
    └── no-blockers-mandatory.md            ← exhaustive research before declaring blocked
```

---

## What the skills do once built (concrete examples)

After installation + Step 3 + ~6-8 weeks of milestones, you can run:

```
# Example 1: create a new epic from a screenshot of a whiteboard
/make-bolt /Users/me/whiteboard.png "implement patient consent capture"

# Example 2: create a new epic from a markdown spec + a URL
/make-bolt docs/feature-x.md https://docs.example.com/spec.html

# Example 3: audit an existing epic against quality standards (read-only)
/make-bolt EP-PATIENT-CONSENT-001 --reverify

# Example 4: run an entire epic to completion (all tickets, parallel waves)
/run-bolt EP-PATIENT-CONSENT-001

# Example 5: run an epic in shadow mode (no auto-merge, just review artifacts)
/run-bolt EP-PATIENT-CONSENT-001 --shadow

# Example 6: resume a paused epic after circuit breaker
/run-bolt EP-PATIENT-CONSENT-001 --resume --confirm-paused
```

---

## Honest expectations (read this before committing)

The master plan is direct about what AI orchestration in 2026 can and cannot do. From §26 and §27 of the master plan, with citations in `plans/2026-05-02-make-bolt-perfection-research.md`:

- **First-run task-level defect rate** with the full max-rigor stack: **3-8%** (down from a 36% baseline for Claude Opus 4.7 on contamination-resistant SWE-bench Pro).
- **Production-escape rate** (defects that survive review and reach prod): **<1%**, plausibly single-digit basis points with calibrated rejection thresholds.
- **Knowledge-graph accuracy ceiling:** **~94-96% aggregate** (~98% intra-language, ~92% cross-language, ~70% on dynamic-dispatch via reflection / DI containers).
- **Zero is not promised.** No production code-intelligence system (Sourcegraph, Glean, CodeQL) claims 100% accuracy. No published evidence supports 0% LLM defect rate. HIPAA-grade discipline does not require zero — it requires measurement, calibration, provenance, and audit, which the spec makes first-class outputs of every run.

If you needed zero, this is the wrong tool. If you need significantly better than current human-only or copilot-assisted norms with a complete audit trail, this is the right tool.

---

## Verifying integrity

Before trusting any file in `plans/`, verify the manifest:

```bash
cd plans && shasum -a 256 -c MANIFEST.sha256
```

All 7 entries must report `OK`. If any fails, the package is corrupt — re-clone from the v1.1.0 tag or a later version.

---

## Versioning

Tags follow semver:

- **Patch (v1.1.x):** typo fixes, citation updates, no semantic change to phases / gates / invariants
- **Minor (v1.x.0):** new gates, new milestones, new optional config keys (backward-compatible with prior bolt.config.yaml)
- **Major (v2.0.0):** changed phase order, removed gates, changed Hard Invariants, breaking config changes

Always pull a tag, not `main`, for reproducibility:

```bash
git clone --branch v1.1.0 https://github.com/lhyman1701/bolts-package.git
```

---

## What this repo is NOT

- **Not a runtime.** No Python or shell scripts here implement `/make-bolt` or `/run-bolt`. Those get built into your target project after Step 3.
- **Not a Claude Code plugin.** Skills must live in the target project's `.claude/skills/`, not in this repo.
- **Not project-specific code.** Zero references to any specific organization, project, team, codebase, or industry domain. The spec is generic; the target project supplies all specifics via `bolt.config.yaml` at M0.
- **Not a guarantee.** Read the "Honest expectations" section above.

---

## If something goes wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `install.sh` reports "MANIFEST verification failed" | File corruption during clone or local edit | Re-clone from the v1.1.0 tag |
| Claude Code refuses the kickoff prompt | Plan mode not enabled | Type `/plan` first, then paste |
| Claude starts writing code without a read-back | You skipped pasting the full prompt | Paste the entire `## Prompt` block, not a summary |
| Milestone close fails on mutation score | Bolt's own test suite must hit ≥ 0.75 | Add tests until threshold met (master plan §25 rule 9) |
| First epic exceeds halt-rate budget | Halt threshold structurally enforced | Halt the run, review halts, fix root causes (master plan §25 rule 8) |
| KG parser fails on > 1% of files | Source-generator output, Razor edge cases, exotic C# 12+ syntax | Add affected paths to `bolt.config.yaml: knowledge_graph.parser_excludes` |

---

## License

All files in this repo are spec / documentation. Use them however serves you. No warranty.
