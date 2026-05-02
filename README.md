# bolts-package

**Version:** v1.0.0 (plan revision dated 2026-05-02)
**Source:** Authored 2026-05-02 from the source project's `make-epic2` + `run-epic2` skills
**Target use:** Build `make-bolt` + `run-bolt` skills in a HIPAA-regulated .NET + Angular project on Azure Repos + Azure Pipelines

This repo is a self-contained build package. A future Claude Code session in a target project clones this repo and uses it as the source of truth for building the two skills.

---

## What's in this repo

```
bolts-package/
├── README.md                                   ← you are here
├── install.sh                                  ← one-command install into a target project
├── transfer-bolt-package.sh                    ← legacy alternate transfer (use install.sh)
├── plans/
│   ├── 2026-05-02-make-bolt-run-bolt-port-spec.md   ← MASTER PLAN, 28 sections, 1,319 lines
│   ├── 2026-05-02-make-bolt-KICKOFF-PROMPT.md       ← canonical prompt (paste into Claude Code)
│   ├── 2026-05-02-make-bolt-kg-research.md          ← knowledge-graph subsystem
│   ├── 2026-05-02-make-bolt-hipaa-research.md       ← HIPAA + AI review + self-improver
│   ├── 2026-05-02-make-bolt-perfection-research.md  ← accuracy + defect-rate ceilings
│   ├── bolt.config.yaml.example                     ← stub config to copy + fill
│   ├── .mcp.json.example                            ← stub MCP server registry
│   └── MANIFEST.sha256                              ← integrity checksums (verify before use)
├── rules/
│   ├── accountability.md
│   ├── diagnostics.md
│   ├── completion-contracts.md
│   └── plans-isolation.md
├── protocols/
│   └── no-blockers-mandatory.md
└── reference/
    └── SOURCE-SKILL-MECHANICS.md                ← abstracted source-skill mechanics (no verbatim code)
```

---

## Quickstart in the target project

```bash
# In the target project's repo root:
cd /path/to/target/project

# 1. Clone bolts-package next to it
git clone https://github.com/lhyman1701/bolts-package.git /tmp/bolts-package

# 2. Run the installer (copies files into .claude/, generates manifest, verifies)
/tmp/bolts-package/install.sh .

# 3. Commit the package files
git add .claude/ .gitignore
git commit -m "chore: install bolts-package v1.0.0 (plan rev 2026-05-02)"

# 4. Open Claude Code
claude

# 5. Inside Claude Code:
/model               # select opus[1m]
/plan                # enter plan mode
cat .claude/plans/2026-05-02-make-bolt-KICKOFF-PROMPT.md
# Paste the entire ## Prompt section verbatim into the chat.
# Future-Claude will write a read-back to .claude/plans/2026-05-02-make-bolt-readback.md
# and halt for your acknowledgment before writing any code.
```

---

## Honest expectations

Per `plans/2026-05-02-make-bolt-perfection-research.md`:

- **First-run task-level defect rate** with the full max-rigor stack: **3-8%** (down from 36% baseline). Production-escape rate: **<1%**. Zero is not promised.
- **Knowledge-graph aggregate weighted accuracy ceiling:** **~94-96%** (~98% intra-language, ~92% cross-language, ~70% on dynamic-dispatch).
- HIPAA-grade discipline does not require zero. It requires measurement, calibration, provenance, and audit. The master plan's job is to make those four properties first-class outputs of every run, not to pretend zero is reachable.

---

## Integrity verification

Before relying on any file in `plans/`, verify integrity:

```bash
cd plans && shasum -a 256 -c MANIFEST.sha256
```

All entries must report `OK`. If any fail, the package is corrupt — re-clone from source.

---

## Versioning

The package is pinned to plan revision dated **2026-05-02**. Future revisions are tagged on the `main` branch as `v1.x.x` with semver semantics:

- **Patch (v1.0.x):** typo fixes, citation updates, no semantic change to phases/gates/invariants
- **Minor (v1.x.0):** added gates, added milestones, new optional config keys (backward-compatible)
- **Major (v2.0.0):** changed phase order, removed gates, changed Hard Invariants, breaking config changes

Future-Claude in the target project should reference the package version in `docs/adr/0001-bolt-adoption.md` so retroactive upgrades remain traceable.

---

## Reading order for future-Claude

The kickoff prompt enforces this order, but listed here for human reference:

1. `plans/2026-05-02-make-bolt-run-bolt-port-spec.md` — master plan, READ END TO END
2. `plans/2026-05-02-make-bolt-perfection-research.md` — required before §26-§27 of master plan
3. `plans/2026-05-02-make-bolt-kg-research.md` — KG subsystem deep-dive
4. `plans/2026-05-02-make-bolt-hipaa-research.md` — HIPAA + AI review deep-dive
5. `reference/SOURCE-SKILL-MECHANICS.md` — abstracted source-skill mechanics
6. `rules/*.md` + `protocols/no-blockers-mandatory.md` — anti-laziness contracts

---

## Provenance

This package was generated from the the source project repo (`/path/to/source-project`) on 2026-05-02. The master plan synthesizes:

- Three Explore-agent reports on the source skills' mechanics
- Three deep-research-agent reports (Claude Code best practices, KG approaches, HIPAA + AI safety)
- One perfection-research agent report on accuracy ceilings (~80 citations)
- Three rounds of user disambiguation locking 12 architectural decisions
- 28 sections including hardening (§25), KG ceiling (§26), defect-rate ceiling (§27), and execution-perfection requirements (§28)

Total master plan length: 1,319 lines, 28 sections. Total package size: ~270 KB markdown + reference skills.
