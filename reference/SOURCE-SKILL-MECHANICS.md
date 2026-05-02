# Source-Skill Mechanics — Abstracted Reference

> The original verbatim source code of `make-epic2` and `run-epic2` is **not included** in this package by design. The verbatim code carried project-specific identifiers (team UUIDs, project UUIDs, ticket-tool API keys, domain vocabulary, hardcoded paths) that are inappropriate to redistribute. Instead, this file abstracts the mechanical patterns future-Claude needs to reproduce when building `make-bolt` and `run-bolt`.
>
> The master plan (`plans/2026-05-02-make-bolt-run-bolt-port-spec.md`) describes the *upgrades* over the source skills. This file describes the *mechanics* of the source skills themselves so future-Claude can recognize the patterns being upgraded.

---

## 1. `make-epic2` (the source skill being upgraded to `make-bolt`)

### 1.1 Purpose
Epic + ticket factory. Accepts requirements in any form (free text, PDFs, screenshots, URLs, YAML), researches the domain (internal KB + web), and emits a ticket-tool epic with run-epic2-ready tickets. Guarantees `/run-epic2` can start at P1 without halting at P0.

### 1.2 Three modes
- **CREATE** — new epic from requirements
- **MODIFY** — augment an existing epic with new requirements (only Backlog tickets are mutated; In-Progress and Done are skipped)
- **REVERIFY** — read-only audit of an existing epic against HQC standards; emits a markdown report; never writes

Mode detection: first positional argument matching `^EP-[A-Z0-9-]+$` switches CREATE → MODIFY (or REVERIFY if `--reverify` is also present).

### 1.3 Six phases (CREATE / MODIFY)
1. **INGEST** — parse all input materials (text, .pdf, .md, .txt, .yaml, .json, .png, .jpg, URLs) into a unified requirements file at `<scratch>/requirements-unified.md`
2. **RESEARCH** — sub-agent reads internal KB, related tickets, architecture rules, codebase structure; emits `<scratch>/research-brief.md`
3. **DECOMPOSE** — sub-agent emits ticket candidates as JSON: `{t_id, title, summary, acceptance_criteria, file_scope_claims, dod_category, kb_impact, dependencies, labels, priority, estimate_hours, migration, wave_order}`
4. **VALIDATE** — structural checks: file_scope_claims non-empty, ACs non-empty + measurable + non-vague, estimate ≤ 4h, title ≤ 50 chars, DAG acyclic (Tarjan SCC), REG-1..6 coverage, migration serialization, no service-root paths
5. **DIFF** — generate human-readable markdown diff at `<plans>/make-epic2-<EPIC>-diff.md`; **pause** for explicit `approve` from user
6. **WRITE** — only after approval: idempotent ticket creation via label-keyed search; never modifies In-Progress or Done tickets; commits scaffolding files (path-claims.yaml, policy.yaml) to repo

### 1.4 Halt-Quality Contract — measurable-AC verbs (regex)
```
\b(assert|verify|confirm|check|validate|pass|succeed|return|output|contain|
   match|equal|exist|create|load|fetch|insert|update|delete|row count|
   exit code|http \d|pytest|curl|SELECT)\b
```

### 1.5 Halt-Quality Contract — vague-phrase rejection (regex)
```
\b(check that it works|make sure|ensure it|should work|verify it works|
   appears to|seems like|might be|could be)\b
```

### 1.6 Idempotency
Issue creation searches by labels first (`epic:<EPIC>`, `t-id:<TID>`); creates only if absent. Comment creation prepends `<!-- run-epic2:<key> -->` marker; skips if marker already present in last 50 comments. Relations check existing list before creating.

---

## 2. `run-epic2` (the source skill being upgraded to `run-bolt`)

### 2.1 Purpose
Autonomous per-epic executor. Picks DAG-ready tickets in waves, spawns `Agent` sub-agents with `isolation="worktree"`, merges serially with KB-sync + cross-merge audit, runs reopen engine on regression / KB-break / mandatory-test changes / supersession.

### 2.2 Phase order
- **P0 EPIC-INIT** — graph build + gap detection + path-claims signoff
- **P0.5 ADOPT** — brown-field history recovery + retroactive grading (skipped if green-field)
- **P1+P2+P3 wave loop** — plan → fan-out → merge (until idle or paused)
- **P4 EPIC-CLOSE** — final reopen sweep, regression, REG execution, summary

### 2.3 Hard Invariants (17, abridged)
1. No direct-to-main commits (every change via PR + auto-merge)
2. No `--admin` merge unless `policy.allow_admin_merge: true`
3. No halt without research (halt-validator rejects non-compliant halts)
4. Sub-agent scratch dir is **outside** the worktree (`~/.run-<skill>/scratch/<run-id>/<TID>/`)
5. Worktrees are harness-managed via `Agent isolation="worktree"`
6. Audit-worktree git ops go through a single `audit_writer` thread queue
7. Ticket-tool write mutations locked via module-level `threading.Lock()`
8. No KB write without validators passing
9. No silent skips — every skipped gate emits `<gate>_SKIPPED` with rationale
10. Policy versioning — any change bumps `policy_version`, prior copied to `policy-history/`
11. Cloud deploy never invoked from this skill
12. All ticket mutations idempotent via stable labels — no fuzzy matching
13. Frozen sub-agent prompt template is single source of truth
14. Repo identifier hardcoded once (config-driven)
15. Concurrency via Python `threading.Thread` + `threading.Lock` (not asyncio / multiprocessing)
16. Pre-commit `--no-verify` NEVER bypasses gitleaks
17. Migrations run serially — never two migration tickets in same wave

### 2.4 Wave partitioning rules
- DAG-ready tickets only (`blocked_by` empty)
- Gate-first filter (gate tickets, identified by `[GATE]` literal in title, run alone if any are ready)
- No path-overlap collisions (graph edges)
- No declared-scope-paths intersection (service-root paths excluded from check)
- Greedy sort by `(priority, phase_order, ticket_id)` ascending
- Migration serialization (one per wave, alone)
- Wave size capped at `--max-parallel` (default 4 first run, 8 once stable)

### 2.5 Reopen engine — five triggers
- **(a) Regression-attribution** — new test failures vs baseline; `git blame` test + sources; rank by `0.5*recency + 0.5*scope_overlap`; reopen if `state == "Done"` AND confidence ≥ 0.6
- **(b) KB-break** — validator failure → `json_path` → provenance → atom_id → `git blame` → ticket
- **(c) Mandatory test type** — every Done ticket whose `merged_at < effective_date` AND missing the required test type for its scope
- **(d) Supersession** — `supersedes:` frontmatter from new research/decision MD files
- **(e) Standards-sweep** — full re-evaluation against current `policy.yaml` (auto-runs at P0.5 ADOPT)

Storm protection: `policy.max_reopens_per_run = 5`, `policy.max_reopens_per_ticket = 2`, plus `regression-quarantine.yaml` for known-flaky tests.

### 2.6 Halt-Quality Contract — every halt-N.md must contain
```yaml
category: <enum>
detection:
  what_failed: <specific signal>
  evidence_files: [<paths>]
research_performed:
  authoritative_sources_consulted:
    - url: <authoritative-source>
      retrieval_timestamp: <ISO-8601 ≤ 30 min before halt>
      relevant_excerpt: <quote>
  hours_of_research_before_halting: <decimal>
recommended_action:
  primary:
    description: <single concrete next step>
    evidence: <why — cite [N]>
    estimated_effort: <hours>
    risk: <low|med|high + why>
  alternates:
    - description: <option B>
      rejected_because: <evidence-based reason citing [N]>
unblocking_decision_required_from_human: <one specific question>
```

Forbidden in halts: empty authoritative-sources, vague phrases ("review and decide", "consider options"), missing alternates, copy-pasted from prior halts (Levenshtein ≥ 0.85), missing `[N]` evidence cites.

### 2.7 KB-sync workflows
Detect change type from `git diff --name-only base_sha...HEAD`:
- **A** (JSON-only): index_json_values → propose_provenance → build_<family>_provenance → validate_kb → validate_provenance
- **B** (MD-only OR both): parse_md_atoms → reconcile_backrefs → A
- **C** (new JSON): schema check → A
- **D** (schema change): halt — require human ADR

### 2.8 State persistence
- **Local state dir** (gitignored): `.lock` (PID + start_ts), `state.duckdb` (tickets, leases, agent_invocations, adoption_grades, reg_executions, meta), `audit-wt/` (orphan branch worktree), `status.json`, `checkpoint.json`
- **Per-ticket scratch dir** (outside repo): `status.json`, `events.jsonl` (≤ 4096 bytes/line), `decisions/NNNN-*.md`, `manifest.json`, `rejected-halts/`
- **Committed audit record** (orphan branch): `graph.json`, `path-claims.yaml`, `EPIC-INIT-SIGNOFF.md`, `adoption-report.md`, `events.jsonl`, `tickets/<TID>/halt-N.md`, `tickets/<TID>/manifest.json`, `summary.md`

### 2.9 Sub-agent manifest schema (returned from every ticket)
```json
{
  "schema_version": "1.0",
  "ticket_id": "<TID>",
  "result": "success | halt | failed",
  "branch": "<branch>",
  "commit_sha": "<sha or null>",
  "ready_to_push": true,
  "files_changed": [...],
  "tests_added": [...],
  "coverage_delta": {"line": 0.04, "branch": 0.03},
  "mutation_score": 0.74,
  "mutation_runner": "mutmut | stryker | null",
  "kb_writes": [...],
  "kb_sync": {"change_type": "json_only|md_only|both|new_json|schema|noop", "validators_passed": true},
  "tool_calls": [{"name": "...", "ts": "...", "analysis_adr": "...", "decision_doc_path": "..."}],
  "cost": {"input_tokens": 0, "output_tokens": 0, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0},
  "halt_reason": null,
  "halt_recommendations": []
}
```

### 2.10 Quality gates
| Gate | Phase | Halt category |
|---|---|---|
| REG-1..6 ticket presence | P0 | regression_tickets_missing |
| KB currency | P0 | kb_currency_drift |
| Path-claims complete | P0 | path_claims_incomplete |
| DAG acyclic | P0 | dag_cycle_detected |
| 7-criterion preflight | sub-agent | preflight_insufficient |
| TDD coverage ≥ floor | sub-agent | coverage_below_bar |
| Mutation score ≥ floor | sub-agent | mutation_below_bar |
| KB validators | sub-agent + P3 | kb_validator_fail |
| Pre-push smoke | P3 | pre_push_gate_fail |
| Post-merge regression | P3 | triggers reopen-(a) |
| REG-Done check | P4 | regression_tickets_not_complete |

### 2.11 Auto-resolve ladders
- **coverage_below_bar / mutation_below_bar**: gap < 5% → research + generate tests, retry max 2×
- **kb_validator_fail**: clean-tree precondition; revert KB changes; re-run workflow A/B/C; retry budget = 1
- **pre_push_gate_fail**: parse last 200 lines of failing target → research lookup → 1 retry
- **ci_timeout**: auto-retry CI poll once (extra 30 min)
- **pre_commit_violation**: format hooks (black, isort, prettier, ruff-format) auto-fix + re-stage; gitleaks / mypy / ruff-non-format are real signals

### 2.12 Circuit breaker
3 consecutive waves with at least one of `{mutation_below_bar, coverage_below_bar, kb_validator_fail, pre_push_smoke_failed, preflight_failed, regression_tickets_not_complete}` → epic paused. Resume requires `--resume --confirm-paused`.

---

## 3. Branch + commit conventions (source skills)
- Work branches: `<skill-prefix>/<epic-slug>/<ticket>` (created by harness via `isolation="worktree"`, then renamed post-hoc, then pushed immediately to survive worktree cleanup)
- Audit branch: `<skill-prefix>/audit/<epic>` (orphan)
- Commit message: `feat(<epic>): <title> (<TID>)\n\nTickets: <TID>[, <TID>...]\n<body>` — the `Tickets:` line is mandatory and parsed by reopen-(a)

---

## 4. What the source skills did NOT do (and `make-bolt` / `run-bolt` MUST do)
- No knowledge graph maintenance — bolt adds DuckDB + Tree-sitter KG (master plan §7, §26)
- No app-type detection — bolt adds 7-profile detector (master plan §10)
- No self-improvement loop — bolt adds two-tier with allowlist (master plan §9)
- No mandatory AI-reviewer fan-out — bolt adds 3 reviewers in HIPAA mode (master plan §11)
- No first-run hardening / mock harness / shadow mode — bolt adds (master plan §25)
- No calibrated KG confidence per edge — bolt adds Platt calibration with ECE < 0.05 target (master plan §26.2)
- No best-of-N + cross-family ensemble + property-based testing + targeted formal verification — bolt adds (master plan §27)

---

## 5. What this file does NOT contain
- No verbatim source code from the source skills (omitted by design)
- No project-specific UUIDs, team IDs, or API keys
- No domain vocabulary tied to the original project's industry niche
- No file paths from the source-project repo

If future-Claude needs the verbatim source skills for any reason, the source-project owner can supply them out-of-band; they are not part of this redistributable package.
