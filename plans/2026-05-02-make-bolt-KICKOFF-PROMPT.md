# `make-bolt` + `run-bolt` — Canonical Kickoff Prompt

> **Version:** v1.0.0 (pinned to master plan revision dated 2026-05-02)
> **Master plan:** `.claude/plans/2026-05-02-make-bolt-run-bolt-port-spec.md` (27 sections, 1,240 lines)
> **Research files:** `.claude/plans/2026-05-02-make-bolt-kg-research.md`, `.claude/plans/2026-05-02-make-bolt-hipaa-research.md`, `.claude/plans/2026-05-02-make-bolt-perfection-research.md`
> **Reference (gitignored):** `.claude/reference/make-bolt/`, `.claude/reference/run-bolt/`, `.claude/reference/2026-04-25-run-bolt-design.md`
>
> **Usage:** Open Claude Code in the new project. Type `/plan` to enter plan mode. Paste the entire `## Prompt` section verbatim. Do not paraphrase, do not summarize, do not omit lines. Future-Claude reads this prompt as a contract.

---

## Pre-flight (run once before pasting the prompt)

Verify all six files are present and uncorrupted:

```bash
test -f .claude/plans/2026-05-02-make-bolt-run-bolt-port-spec.md && \
test -f .claude/plans/2026-05-02-make-bolt-kg-research.md && \
test -f .claude/plans/2026-05-02-make-bolt-hipaa-research.md && \
test -f .claude/plans/2026-05-02-make-bolt-perfection-research.md && \
test -f .claude/plans/2026-05-02-make-bolt-KICKOFF-PROMPT.md && \
test -d .claude/reference/make-bolt && \
test -d .claude/reference/run-bolt && \
test -f .claude/reference/2026-04-25-run-bolt-design.md && \
test -d .claude/rules && \
test -f .claude/protocols/no-blockers-mandatory.md && \
echo "PREFLIGHT-OK" || echo "PREFLIGHT-FAIL — restore missing files before kicking off"
```

Also confirm Claude Code session has Opus 4.7 with 1M context (run `/model` and select `opus[1m]`).

---

## Prompt

```
You are building two slash-command skills (make-bolt + run-bolt) in this repo
per the master plan at .claude/plans/2026-05-02-make-bolt-run-bolt-port-spec.md.

== Required reading (in this order, before writing any code) ==

1. .claude/plans/2026-05-02-make-bolt-run-bolt-port-spec.md
   (master plan, 27 sections, 1,240 lines — read END TO END, not skimmed)
2. .claude/plans/2026-05-02-make-bolt-perfection-research.md
   (KG accuracy + first-run defect-rate ceilings; required before §26-§27)
3. .claude/plans/2026-05-02-make-bolt-kg-research.md
   (knowledge-graph subsystem + DuckDB DDL)
4. .claude/plans/2026-05-02-make-bolt-hipaa-research.md
   (HIPAA + AI review + self-improvement + app-type detector + prompt skeletons)
5. .claude/reference/make-bolt/, .claude/reference/run-bolt/,
   .claude/reference/2026-04-25-run-bolt-design.md
   (make-bolt + run-bolt — read for mechanics, do not copy verbatim; bolt is an
   upgrade not a clone)
6. .claude/rules/*.md and .claude/protocols/no-blockers-mandatory.md
   (anti-laziness contracts)

After reading, write to .claude/plans/2026-05-02-make-bolt-readback.md a one-page
read-back: what you understood, what's locked, what's TBD, where you intend to
deviate from the plan and why. STOP and wait for human acknowledgment of the
read-back before any further work.

== Build constraints (non-negotiable, sourced from named sections) ==

- Project profile: .NET + Angular/React on Azure Repos + Azure Pipelines, full
  HIPAA mode, ticket tool TBD until build-time. (§2 Decisions Locked, §6 Target
  Profile)
- All 22 Hard Invariants apply: 17 designed for run-bolt + 5 new in §23. No
  exceptions. Re-read §23 before each phase.
- §13 anti-laziness directives + §21 anti-drift directives apply to YOU
  (future-Claude) as well as to bolt's sub-agents. The forbidden phrases in
  .claude/rules/accountability.md apply to your status reports.
- §25 First-Run Hardening Protocol is non-negotiable (10 rules, milestone hooks,
  sign-off in §25.4).
- §26 KG accuracy upgrades (12 mandatory items) and §27 orchestrator upgrades
  (14 mandatory items) are non-negotiable in HIPAA mode. The honest framing in
  §26.1 and §27.1 stands: zero is not promised, calibrated confidence is.
- §27.5 sign-off requirements supersede §25.4 sign-off.

== Build order ==

Follow the §18 milestone schedule strictly. Each milestone closes only when:
- Done Checklist items for that milestone are ticked with EVIDENCE (not
  assertions). See .claude/rules/completion-contracts.md.
- Pre-milestone self-audit by code-reviewer + security-reviewer sub-agents
  (§25 rule 10) returns no unaddressed request_changes.
- A milestone-end status report is appended to
  .claude/plans/2026-05-02-make-bolt-build-log.md with: what shipped, what
  tests prove it, what known gaps exist, what the next milestone needs from
  the user.

Start at M0. Before starting M0, surface the §19 open questions to me via
ExitPlanMode and wait for answers:

  1. Ticket tool selection date — which adapter ships first?
  2. Pilot epic — what's the first real epic the user wants run-bolt to drive?
  3. Embeddings vendor — which BAA-vetted option (Bedrock / Vertex / Azure
     OpenAI / bge-m3 air-gapped)?
  4. CI required-status-check names — list per Azure Pipeline.
  5. CODEOWNERS format — GitHub-style or Azure DevOps-style?
  6. Mutation runner version pinning (Stryker.NET, StrykerJS) — which versions?
  7. AI reviewer prompt skeletons — user reviews before M3.5.
  8. Self-improver L0 allowlist — confirm §6 list before M4.5.
  9. Hard Invariants — confirm all 22 acceptable as written before M0 closes.

== Forbidden actions ==

- Do not start writing code before the read-back in step 1 is acknowledged.
- Do not commit code that imports any vendor-specific module
  (linear_client, gh CLI, github API client) outside an adapter.
- Do not skip the §25 mock harness milestone (M0.25). Real adapters are wired
  ONLY after mock-mode smoke is green twice consecutively.
- Do not enable self_improver before M5-pilot+1 (§25 rule 7).
- Do not flip HIPAA-mode merge gate to enforcing before the §27 calibration
  epic completes (§25 rule 6 + §27 #13).
- Do not auto-merge the first real-adapter epic — it runs in --shadow with
  human SHADOW-SIGNOFF.md (§25 rule 3).
- Do not consume KG edges below their confidence threshold silently. Every
  consumer threshold per §26.2 #11. Audit at PR-open time.
- Do not call any AI vendor outside the BAA allowlist (§10.3) without an
  ADR-pinned override.
- Do not weaken any halt-quality contract or invariant when porting to .NET-
  specific languages.
- Do not claim "done", "complete", "fixed", "working", "implemented" without
  evidence per .claude/rules/accountability.md.

== Required outputs at every milestone close ==

For each milestone Mn:
- All Done Checklist items for that Mn ticked in
  .claude/plans/2026-05-02-make-bolt-build-log.md with file:line evidence.
- Pre-milestone self-audit transcript saved at
  docs/run-bolt/build-audits/Mn-self-audit.md.
- Mutation score for Mn-touched code ≥ 0.75 (§25 rule 9 — bolt's own bar).
- All §27.3 evidence-chain fields produced for any test PR opened during Mn.
- A "what could go wrong on first user-visible run" risk register entry per Mn,
  appended to .claude/plans/2026-05-02-make-bolt-risk-register.md.

== Sign-off requirements (cumulative, from §25.4 + §27.5) ==

Future-Claude may not mark M5 done without all of:
- Mock-mode smoke green twice consecutively (different timestamps)
- Three markdown_stub end-to-end epics merged cleanly
- One shadow-mode real-adapter epic with SHADOW-SIGNOFF.md from the user
- One AI-reviewer calibration epic with verdicts reviewed by user
- Bolt's own mutation score ≥ 0.75 enforced in CI
- All pre-milestone self-audits closed
- KG aggregate weighted accuracy ≥ 0.92 on real codebase, ECE < 0.05
- §27 14 orchestrator upgrades implemented; auto-merge thresholds set per
  ticket class from a held-out 50-ticket gold-set
- Per-PR evidence chain (§27.3) committed for every merged ticket in the
  pilot epic
- 7-day post-merge regression watcher running on pilot epic

== Honest expectations ==

Published evidence (§27.1) caps first-run task-level defect rate at 3-8% with
the full max-rigor stack and production-escape rate at <1%. Zero is not
promised. KG accuracy ceiling is ~94% aggregate (§26.1). Anyone — including
you — claiming higher must produce evidence.

== Stop conditions (halt the build, surface to human) ==

- Any of the §25.4 / §27.5 sign-off items cannot be satisfied with evidence.
- Any KG calibration ECE > 0.05 after 3 recalibration attempts.
- Any cross-family AI judge dissent on auth, PHI, schema, or regulated diffs
  that the calibrated threshold would otherwise auto-merge.
- Three consecutive milestones with halt-rate > §6 halt_audit_threshold.
- Any drift in this prompt vs the master plan — STOP and ask the user. The
  master plan is the canonical source; if the prompt and the plan disagree,
  the plan wins.
```

---

## Companion artifacts that ship with the package

| File | Purpose |
|---|---|
| `.claude/plans/2026-05-02-make-bolt-run-bolt-port-spec.md` | Master plan (27 sections, 1,240 lines) |
| `.claude/plans/2026-05-02-make-bolt-kg-research.md` | KG subsystem + DuckDB DDL |
| `.claude/plans/2026-05-02-make-bolt-hipaa-research.md` | HIPAA + AI review + self-improver + detector + prompt skeletons |
| `.claude/plans/2026-05-02-make-bolt-perfection-research.md` | KG/orchestrator accuracy ceilings + 80+ citations |
| `.claude/plans/2026-05-02-make-bolt-KICKOFF-PROMPT.md` | This file. Pinned canonical kickoff. |
| `.claude/plans/2026-05-02-make-bolt-build-log.md` | Created by future-Claude at M0; appended at every milestone close |
| `.claude/plans/2026-05-02-make-bolt-readback.md` | Created by future-Claude in step 1; gates code start |
| `.claude/plans/2026-05-02-make-bolt-risk-register.md` | Created by future-Claude at M0; one entry per Mn |
| `.claude/reference/BOLT-MECHANICS.md` | Mechanical contract for both skills (phase order, halt-quality contract, gates, etc.) |
| `.claude/rules/accountability.md` | Anti-evasion contracts |
| `.claude/rules/diagnostics.md` | Diagnostic-first protocol |
| `.claude/rules/completion-contracts.md` | Completion contract pattern |
| `.claude/rules/plans-isolation.md` | Local-plans-only rule |
| `.claude/protocols/no-blockers-mandatory.md` | No-blockers protocol |
| `bolt.config.yaml.example` | Stub config; future-Claude renames to `bolt.config.yaml` and fills `<filled at build time>` placeholders at M0 |
| `.mcp.json.example` | Stub MCP config listing context7, mcp__memory__, filesystem, azure_devops, atlassian_jira |

---

## Manifest checksum (commit alongside the package)

After writing all files, generate a manifest checksum so future-Claude can
verify the package is intact:

```bash
cd .claude/plans
sha256sum 2026-05-02-make-bolt-*.md > MANIFEST.sha256
```

Future-Claude verifies on session start:

```bash
cd .claude/plans && sha256sum -c MANIFEST.sha256 || echo "PACKAGE-CORRUPT"
```

If checksum fails, halt — the package is corrupt and the prompt cannot be
trusted.
