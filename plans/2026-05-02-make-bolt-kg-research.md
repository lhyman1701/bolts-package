# Codebase Knowledge-Graph Spec for make-bolt + run-bolt

**Stack target:** .NET (C#) backend, Angular/React/TS/JS/HTML/SCSS frontend, Razor (.cshtml) views, SQL, Azure-hosted, HIPAA-regulated.
**Decision (locked):** local-first. Tree-sitter parsers + DuckDB + FTS, optional embeddings.
**Author intent:** evidence-backed, opinionated. Every recommendation has a URL.

> Note on plans-isolation: harness forced this file path under `~/.claude/plans/`. Per `.claude/rules/plans-isolation.md`, the canonical copy must be mirrored to `.claude/plans/` in the project repo before this plan is acted on. This file is the deliverable.

---

## 1. Tree-sitter grammars and incremental parsing

### What's mature, what's flaky

| Language | Recommended grammar | Maturity (May 2026) | Notes |
|---|---|---|---|
| **C#** | `tree-sitter/tree-sitter-c-sharp` v0.23.5 (Apr 14 2026) | **Mostly mature** | README claims "comprehensive support C# 1 through 13.0" but tracker has 28 open issues incl. #329 (record class with primary ctor parses with errors) and #236 (file-scoped types). Records, file-scoped namespaces, primary constructors *on regular classes*: works. Records-with-primary-ctor and source-generators: edge cases. ([repo](https://github.com/tree-sitter/tree-sitter-c-sharp), [primary ctor issue #329](https://github.com/tree-sitter/tree-sitter-c-sharp/issues/329), [file-scoped issue #236](https://github.com/tree-sitter/tree-sitter-c-sharp/issues/236), [PyPI 0.23.5](https://pypi.org/project/tree-sitter-c-sharp/)) |
| **TypeScript / TSX** | `tree-sitter/tree-sitter-typescript` v0.23.2 (May 2025) | **Stable but coasting** | npm Snyk page reports "Inactive" — no release in ~12 months. 321 dependents, well-exercised. Two grammars (`typescript`, `tsx`). Safe to use; just don't expect rapid adoption of new TS proposals. ([npm](https://www.npmjs.com/package/tree-sitter-typescript), [Snyk advisor](https://snyk.io/advisor/python/tree-sitter-typescript)) |
| **JavaScript** | `tree-sitter/tree-sitter-javascript` | **Mature** | Reference implementation, used everywhere. ([repo](https://github.com/tree-sitter/tree-sitter-javascript)) |
| **HTML** | `tree-sitter/tree-sitter-html` | **Mature** | Standard, widely embedded. ([repo](https://github.com/tree-sitter/tree-sitter-html)) |
| **SCSS** | `tree-sitter-grammars/tree-sitter-scss` (last update Mar 2026) | Adequate | Lower star count but actively maintained in the `tree-sitter-grammars` org which absorbs orphaned grammars. ([org](https://github.com/tree-sitter-grammars)) |
| **Razor (.cshtml)** | **Pick one and document the choice; none are great** | **Flaky** | `tree-sitter/tree-sitter-razor` is officially WIP and stale (last touched 2021). `tris203/tree-sitter-razor` and `swimmio/tree-sitter-razor-csharp` are community alternatives, both partial. **Recommendation:** treat `.cshtml` as opaque text + extract C# blocks via regex bridge → re-parse the extracted C# with `tree-sitter-c-sharp`. Do not block KG v1 on a perfect Razor parser. ([WIP repo](https://github.com/tree-sitter/tree-sitter-razor), [tris203](https://github.com/tris203/tree-sitter-razor), [swimmio](https://github.com/swimmio/tree-sitter-razor-csharp)) |
| **SQL** | `DerekStride/tree-sitter-sql` v0.3.11 (Oct 2025) | **Active, permissive** | "General/permissive SQL grammar." References Postgres/SQLite/MariaDB syntax docs. T-SQL specifics (e.g. `[brackets]`, `OUTPUT` clause) not perfectly handled — be prepared to fall back to lexical tokenization for T-SQL-isms. ([repo](https://github.com/DerekStride/tree-sitter-sql), [releases](https://github.com/DerekStride/tree-sitter-sql/releases)) |

### Library bindings: pick one, stick with it

- **`py-tree-sitter` (Python bindings) — RECOMMENDED for the orchestrator skill.** Mature (current 0.25.2). Importantly, **0.25.x broke ABI vs 0.23.x** — pin both `tree-sitter` and every `tree-sitter-<lang>` package to the same compatible major. The single most common production failure is "Language's ABI is too new: 14" — caused by mixing versions. ([py-tree-sitter docs](https://tree-sitter.github.io/py-tree-sitter/), [ABI breakage tracking issue](https://github.com/tree-sitter/py-tree-sitter/releases))
- **Node bindings:** equally functional, but Python's ecosystem is friendlier for the kind of stitch-together-with-DuckDB code we'll write.
- **CLI:** parsing-only; no API. Fine for one-shot dumps, useless for incremental in-process updates.

**Recommendation for v1:**
- C#, TS/TSX, JS, HTML, SCSS, SQL: tree-sitter via py bindings.
- Razor: tree-sitter HTML for the static layout + regex-extract `@{ ... }`/`@code { ... }` blocks → tree-sitter-c-sharp. Document the limitation.
- Pin `tree-sitter==0.23.x` + matching grammar versions until the ABI dust settles. Bump in lockstep.

### Incremental parsing semantics

Tree-sitter supports `Parser.parse(source, old_tree=old_tree)` — feeds the old syntax tree as a hint, only re-parses changed regions. Speedup is significant on small edits. Critical because make-bolt/run-bolt will re-parse on every commit. ([Strumenta on incremental parsing](https://tomassetti.me/incremental-parsing-using-tree-sitter/), [tree-sitter README](https://github.com/tree-sitter/tree-sitter))

---

## 2. KG entity/relation schema — what to capture

Synthesizing across **Aider repomap**, **Codebase-Memory (arxiv 2603.27277)**, **code-review-graph**, **Sourcegraph SCIP**, **GitHub stack-graphs**, **Glean**, **Joern code-property-graph**:

### Nodes (entities)

| Category | Node types |
|---|---|
| **Repo structure** | `repo`, `commit`, `branch`, `package`, `folder`, `file` |
| **Symbols** | `namespace`, `class`, `interface`, `record`, `struct`, `enum`, `method`, `function`, `property`, `field`, `constructor`, `parameter`, `local_var`, `type_param` |
| **Frontend** | `component`, `directive`, `service` (Angular/React), `hook`, `route_definition` |
| **Backend** | `controller`, `endpoint` (HTTP verb + path), `middleware`, `dto`, `handler` |
| **Data layer** | `db_entity` (EF Core class), `db_table`, `db_column`, `migration`, `db_index`, `foreign_key` |
| **Tests** | `test_class`, `test_case`, `fixture` |
| **Docs/governance** | `adr`, `doc`, `code_owner`, `team` |
| **HIPAA** | `phi_field` (annotated/inferred), `phi_endpoint`, `audit_log_sink` |

### Edges (relations)

`CALLS`, `CALLED_BY` (inverse), `OVERRIDES`, `IMPLEMENTS`, `INHERITS`, `CONTAINS`, `DEFINES`, `REFERENCES`, `IMPORTS`, `EXPORTS`, `USES_TYPE`, `THROWS`, `RETURNS`, `READS`, `WRITES`, `TESTS`, `TESTED_BY`, `ROUTES_TO` (route → handler), `FE_CALLS_BE` (component → endpoint), `MAPS_TO_TABLE` (entity → table), `MIGRATED_BY`, `OWNS` (codeowner → file), `AFFECTS` (ADR → file), `CARRIES_PHI`, `LEAKS_PHI_TO` (taint edge).

Each edge carries: `confidence ∈ [0.0, 1.0]` (extracted vs inferred vs ambiguous), `source_method` (tree-sitter-query | regex | semantic-LSP | LLM-inferred), `first_seen_commit`, `last_seen_commit`.

### Schema influence map

- **Sourcegraph SCIP** — symbol IDs as human-readable strings, occurrences with role bitmask (definition/reference/read/write). Steal the symbol-ID format. ([SCIP announce](https://sourcegraph.com/blog/announcing-scip), [scip-dotnet](https://github.com/sourcegraph/scip-dotnet))
- **CodeQL `.dbscheme`** — relations are tables; queries are SQL-ish. Confirms our DuckDB-as-graph approach is the same shape big-co tools use. ([CodeQL overview](https://codeql.github.com/docs/codeql-overview/about-codeql/))
- **Joern CPG** — AST + CFG + PDG fused into one graph; supports taint analysis natively. We don't need full CFG/PDG at v1, but the **CARRIES_PHI / LEAKS_PHI_TO** edges follow Joern's source→sink pattern. ([Joern CPG docs](https://docs.joern.io/code-property-graph/), [CPG spec](https://cpg.joern.io/))
- **Aider repomap** — file-as-node graph, PageRank-personalized to chat context, single SQLite cache keyed by `(file_path, mtime)`. We adopt this as our caching pattern. ([Aider blog](https://aider.chat/2023/10/22/repomap.html))
- **Codebase-Memory (arxiv 2603.27277)** — closest precedent: SQLite KG with `XXH3` content-hash incremental updates, reports ~4x speedup vs full re-index, 83% answer quality at 10x lower tokens vs file-explorer agent. **This is our north star for evaluation.** ([paper](https://arxiv.org/html/2603.27277v1))
- **GitHub stack-graphs** — file-isolated indexing; cross-file resolution at query time via path-finding. Best name-resolution model for cross-language jumps; Rust impl, harder to embed in Python. Cite as inspiration for cross-language `FE_CALLS_BE`. ([GitHub blog](https://github.blog/open-source/introducing-stack-graphs/), [paper](https://arxiv.org/pdf/2211.01224))
- **Glean** — Angle (Datalog-ish), facts in RocksDB. Validates the "facts as relational tables" model at FB scale. ([Meta engineering](https://engineering.fb.com/2024/12/19/developer-tools/glean-open-source-code-indexing/))
- **code-review-graph** — drop-in MCP precedent that already does what we want at smaller scale (28 MCP tools, sub-2-sec updates on 2,900-file projects). Confidence tiers (EXTRACTED/INFERRED/AMBIGUOUS) — adopt verbatim. ([repo](https://github.com/tirth8205/code-review-graph))

---

## 3. DuckDB schema patterns

### Why DuckDB is the right call

- Columnar, vectorized — neighbor-lookup queries (`callers of X`) are scans that DuckDB eats for breakfast. ([motherduck](https://motherduck.com/blog/duckdb-cognee-sql-analytics-graph-rag/))
- Recursive CTEs with the new `USING KEY` clause (DuckDB 1.x) handle call-graph traversal with cycle detection efficiently — earlier set-based recursive CTEs blow memory on cyclic graphs. ([DuckDB USING KEY blog](https://duckdb.org/2025/05/23/using-key), [SIGMOD paper](https://duckdb.org/science/bamberg-using-key-sigmod/))
- Single-file embeddable database — no daemon, no port, fits the local-first contract.

### Extensions that matter

| Extension | Status (May 2026) | Use it for | Caveats |
|---|---|---|---|
| `fts` | **Experimental** | BM25 search over symbol names, doc strings, file paths | Index must be **rebuilt** on data change — no incremental updates. Build once per KG refresh, not per file. ([DuckDB FTS](https://duckdb.org/docs/current/core_extensions/full_text_search.html), [DuckDB text analytics](https://duckdb.org/2025/06/13/text-analytics)) |
| `vss` | **Experimental** | HNSW over `FLOAT[N]` array columns for embedding similarity | Persistence is the killer caveat: persistence is opt-in, full re-serialization at every checkpoint, **WAL recovery not implemented** → crash = corrupt index. **For v1: use VSS only on in-memory tables, rebuild from a separate persistent embeddings table on startup.** ([DuckDB VSS](https://duckdb.org/docs/current/core_extensions/vss)) |
| `json` | Stable | Storing tree-sitter query results, attribute payloads, raw symbol metadata | Native `JSON` type. ([DuckDB JSON](https://duckdb.org/docs/current/data/json/overview.html)) |
| `duckpgq` | Community v0.1.0+ (DuckDB 1.1.3+) | SQL/PGQ — `MATCH (n)-[e]->(m)` syntax over our vertex/edge tables | Now persistent across sessions. Optional ergonomic layer; SQL recursive CTEs cover the same ground. ([DuckPGQ](https://duckpgq.org/), [DuckPGQ property graph](https://duckpgq.org/documentation/property_graph/)) |
| `sqlite_scanner` | Stable | Reading existing SQLite caches (Aider's, code-review-graph's) for migration | Useful for bootstrap. |

### Production cautions to ship with the spec

1. **VSS in-memory only** until DuckDB ships proper persistence. Plan: persistent `code_embedding(symbol_id, vec FLOAT[N])` table → load + `CREATE INDEX ... USING HNSW` on startup of make-bolt/run-bolt.
2. **FTS rebuild on KG refresh** — drop and re-`PRAGMA create_fts_index(...)` after a commit's worth of changes are merged into the KG. Cheap (seconds) for a few-million-row symbol table.
3. **DuckPGQ optional** — don't make the core KG depend on a community extension. Use it for ergonomic graph queries from the orchestrator; ship recursive-CTE equivalents as fallbacks.

---

## 4. Incremental update strategy

Strategy is taken almost verbatim from rust-analyzer's salsa, Codebase-Memory, and Aider:

### Inputs per refresh
- `git diff --name-status <prev_sha>..<new_sha>` — added/modified/deleted/renamed files
- For each surviving file: `mtime` (cheap pre-check) + `xxh3_64(content)` (authoritative)

### Pipeline
1. **File-level cache hit:** if `(path, content_hash)` already in `file_index` → skip re-parse. Mirrors Aider's `mtime` cache and Codebase-Memory's XXH3.
2. **Re-parse changed files:** tree-sitter `parse(source, old_tree)` for incremental. Re-emit symbols + intra-file edges.
3. **Invalidate downstream edges:** delete edges where `src_file = changed` OR `dst_file = changed`. Inter-file edges are recomputed lazily on demand (salsa-style "early cutoff": if a recomputed symbol has the same fingerprint as before, downstream queries can short-circuit). ([rust-analyzer durable incrementality](https://rust-analyzer.github.io/blog/2023/07/24/durable-incrementality.html), [salsa overview](https://rustc-dev-guide.rust-lang.org/queries/salsa.html))
4. **Re-resolve cross-file references:** for each new/changed symbol, re-run name resolution against the unchanged universe. This is the expensive step; budget it.
5. **Update FTS index lazily:** queue rebuilds, debounce 30s. Don't rebuild per-commit if commits arrive in bursts.
6. **Update embeddings selectively:** only re-embed changed *symbols* (not whole files) — embedding cost dominates if granularity is wrong.

### Force-rebuild triggers
- `tags.scm` query files changed (extraction logic mutated)
- Tree-sitter grammar package version bumped
- Schema migration applied (`schema_version` mismatch in `meta` table)

### What we're explicitly NOT doing at v1
- True salsa-style query memoization. Too much engineering for the marginal speedup. We pay the file re-parse cost per commit, which on 10k-file repos is single-digit seconds.
- True stack-graphs name resolution. The tree-sitter-driven heuristic ("symbol name match within import scope") has known false positives but is good enough; tag low-confidence edges and let the LLM disambiguate at query time.

---

## 5. KG maintenance during /run-bolt orchestration

Mapping to the existing `/run-bolt` lifecycle (from `CLAUDE.md` coexistence matrix):

| Phase | KG action | Rationale |
|---|---|---|
| **P0 EPIC-INIT** | If `kg.duckdb` missing or `meta.last_indexed_sha` is stale by >50 commits or >7 days → **full rebuild**. Otherwise incremental from `meta.last_indexed_sha` to `HEAD`. | Bounded freshness without paying full-rebuild cost every run. |
| **P0.5 ADOPT** (brown-field) | Always full rebuild on first adoption — provides clean baseline for grading historical Done tickets. | Mirrors run-bolt's existing ADOPT semantics. |
| **Per-ticket worktree** | Run `kg-bolt update --from-sha <merge-base>` *inside the worktree* writing to a worktree-local `kg.duckdb` (under `~/.run-bolt/scratch/<run-id>/<ANU>/`). Worktree KG is never written back. | Each ticket sees a private snapshot; no cross-ticket contamination. |
| **After ticket merge to integration branch** | Single-writer mainline: `kg-bolt incremental <merged_sha>` writes to canonical `.bolt/kg/kg.duckdb`. Serial; takes a lock. | One source of truth; merge-serial matches run-bolt's merge model. |
| **Schema-change ticket** (migration files touched) | Force full rebuild after merge. | DB schema KG nodes are too entangled for safe incremental update. |
| **Audit-branch model** | KG is an artifact, not source. Build product (DuckDB file) goes into `bolt/audit/<epic>` orphan branch under `docs/run-bolt/<epic>/kg/`. Reproducible from source on any machine. | Don't pollute main with binary blobs; consumers can rebuild from `meta.commit_sha`. |

### Locking
Single mutex lockfile `.bolt/kg/.lock` for the canonical KG. Worktree-local KGs need no lock. Same lock-file pattern as run-bolt's epic lock.

---

## 6. KG-driven gates (precision/recall realism)

Below, **P** = precision (when we flag, are we right?), **R** = recall (when something's wrong, do we catch it?). Estimates based on Codebase-Memory's reported 83% quality and Joern/CodeQL precision lit.

| # | Gate | Description | P/R estimate | Ship at v1? |
|---|---|---|---|---|
| **G1** | **Scope drift** | Ticket claims `services/foo`; KG shows changed-file edges into `services/bar` | P~0.85 / R~0.95 | **Yes** — high signal, easy to compute |
| **G2** | **Dead code added** | New method has zero callers + not exported + not test + not handler | P~0.70 / R~0.80 | **Yes** — exclude obvious cases (event handlers, route handlers, DI-injected) via tag list |
| **G3** | **Blast radius warning** | Method change has N callers > threshold | P~1.0 / R~1.0 (it's a count, not a judgment) | **Yes** — display only, no block |
| **G4** | **Coverage gap** | New public method has no `TESTED_BY` edge | P~0.95 / R~0.70 | **Yes** — false negatives where tests exist but aren't recognized |
| **G5** | **FE→BE contract drift** | FE `fetch('/api/x')` exists but no `endpoint('/api/x')` node, or vice versa | P~0.75 / R~0.85 | **Yes** — most actionable bug class for full-stack monorepos |
| **G6** | **PHI propagation** | New code reads from `phi_field` and writes to a non-`audit_log_sink` (file/log/stdout/HTTP response without `[Authorize]`) | P~0.40 / R~0.60 at v1 | **No** — surface as advisory only; mature into v2 |
| **G7** | **Migration without code** | `migrations/*.cs` adds column but no entity property change | P~0.90 / R~0.90 | **Yes** |
| **G8** | **Owner-not-notified** | PR touches files where CODEOWNERS team isn't a reviewer | P~1.0 / R~1.0 | **Yes** — pure lookup |
| **G9** | **Supersession** | Embedding similarity > 0.92 between new method and existing method, same package | P~0.50 / R~0.60 | **No at v1** — too noisy until embeddings layer is hardened |
| **G10** | **Architectural rule violation** (ARCH-RULE-1 etc.) | Service-layer file imports `HTTPException` etc. | P~0.95 / R~0.95 | **Yes** — encode as KG queries; matches existing `CLAUDE.md` rules |

**Ship at v1: G1, G2, G3, G4, G5, G7, G8, G10.** Defer G6 (PHI) to advisory and G9 (supersession) to v2 once embeddings are stable.

---

## 7. Embeddings layer

### Should we add it?

**Yes, but optional and async.** Embeddings answer questions tree-sitter can't: "find docs about authentication," "is this method semantically a duplicate," "which ADR governs this code path." Without embeddings the KG is structural-only.

### Granularity

**Per-symbol, not per-file.** Files are too coarse (a 1500-line `Service.cs` becomes one fuzzy vector). Functions/methods + classes + ADR/doc paragraphs is the right unit. Codebase-Memory and code-review-graph both chunk at symbol granularity. ([code-review-graph](https://github.com/tirth8205/code-review-graph))

For long methods (>1k tokens), apply secondary 512-token-with-overlap chunking — matches 2026 RAG benchmarks showing 512-token chunks with 10-20% overlap as the sweet spot. ([RAG chunking benchmark guide](https://nandigamharikrishna.substack.com/p/rag-chunking-strategies-and-embeddings))

### Model

`text-embedding-3-large` (OpenAI, 3072 dims). MTEB ~64.6 (March 2026), still top-2 vs Cohere embed-v4. Cost is the concern: ~$0.13/1M tokens. For ~50k symbols × ~200 tokens average = 10M tokens = $1.30 once + delta on changes. Trivial.

Alternative: `bge-m3` (BAAI, free, runnable locally) — competitive on retrieval, multilingual, 8192-token context. **Recommendation: ship with `text-embedding-3-large` for v1, document `bge-m3` as the air-gapped alternative for HIPAA tenants who can't egress code to OpenAI.** ([bge-m3](https://huggingface.co/BAAI/bge-m3), [MTEB](https://github.com/embeddings-benchmark/mteb))

### Storage

Inside DuckDB as `FLOAT[3072]` column. VSS HNSW index is **in-memory only** at v1 (rebuild from persistent table at startup, takes seconds for ~50k vectors). Don't rely on persisted HNSW until DuckDB stabilizes the WAL story. ([DuckDB VSS announcement](https://duckdb.org/2024/05/03/vector-similarity-search-vss))

---

## 8. Comparable open-source projects: steal vs build

| Project | What to steal | What to skip |
|---|---|---|
| **Aider repomap** | mtime cache pattern, PageRank for relevance ranking, tree-sitter `tags.scm` extraction templates per language ([repomap.py](https://github.com/Aider-AI/aider/blob/main/aider/repomap.py)) | Token-budget-driven file selection — orthogonal to our KG goals |
| **Codebase-Memory (arxiv 2603.27277)** | XXH3 content hashing, MCP server pattern, edge confidence scoring (0.0–1.0), 28-tool API surface ([paper](https://arxiv.org/html/2603.27277v1)) | SQLite single-file backend (we use DuckDB for analytics) |
| **code-review-graph** | EXTRACTED/INFERRED/AMBIGUOUS confidence tiers, MCP tool list, sub-2s update target ([repo](https://github.com/tirth8205/code-review-graph)) | nothing — most directly applicable precedent |
| **Sourcegraph SCIP / scip-typescript / scip-dotnet** | Symbol-ID format (`scheme manager package version descriptor...`), occurrence-with-role-bitmask data model ([SCIP](https://sourcegraph.com/blog/announcing-scip), [scip-dotnet](https://github.com/sourcegraph/scip-dotnet)) | Running scip-dotnet itself: last release v0.2.12 in March 2024; works but maintenance is slowing. We'd rather own our tree-sitter pipeline than depend on it. |
| **GitHub stack-graphs** | Per-file-isolated index → query-time path-finding architecture — the right model for cross-language `FE_CALLS_BE` ([blog](https://github.blog/open-source/introducing-stack-graphs/), [paper](https://arxiv.org/pdf/2211.01224)) | Reimplementing in Python is a year of work. Use the architectural idea, not the code. |
| **Glean (Meta)** | Facts-as-tables model, schema-driven approach (`codemarkup.angle` is good reference reading) ([repo](https://github.com/facebookincubator/Glean)) | Angle/Haskell stack — overkill for us |
| **Joern / code-property-graph** | AST+CFG+PDG fusion concept, taint-source/sink encoding for PHI ([Joern](https://docs.joern.io/code-property-graph/), [CPG spec](https://cpg.joern.io/)) | Don't ship CFG/PDG at v1 — AST + call/ref graph is enough |
| **CodeQL `.dbscheme`** | Declarative schema-as-code pattern, query-language-over-relational-tables — confirms our DuckDB approach ([CodeQL](https://codeql.github.com/)) | The QL language itself |
| **tree-sitter-graph** | DSL for declaratively turning tree-sitter parses into graph nodes/edges per language ([repo](https://github.com/tree-sitter/tree-sitter-graph)) | Not strictly needed — `tags.scm` queries cover 80% |

### Net steal list
- Aider's mtime cache pattern + tags.scm templates
- Codebase-Memory's XXH3 + MCP server design
- code-review-graph's confidence tiers + tool inventory
- SCIP's symbol-ID format
- stack-graphs' file-isolation architecture (concept only)
- Joern's source/sink encoding for PHI

---

## 9. HIPAA-relevant additions

Tagging PHI is real, not wishful — Joern, Bearer, and Checkmarx all do it commercially at varying confidence. Ours will start lower-precision but is genuinely useful. ([Bearer + others summary](https://www.augmentcode.com/guides/hipaa-compliant-ai-coding-guide-for-healthcare-developers), [Checkmarx HIPAA taint](https://devsecopsschool.com/blog/codeql/))

### Sources of PHI tags (from highest to lowest confidence)
1. **Explicit attribute:** `[PhiField]`, `[ProtectedHealthInfo]`, or whatever attribute the team standardizes — emit `phi_field` node + `confidence=1.0`.
2. **Field-name regex:** `ssn|mrn|patient_name|dob|date_of_birth|diagnosis|icd10|cpt|...` against `db_column` and `field` nodes — emit with `confidence=0.7`.
3. **Reaches PHI table column:** EF Core entity property maps to a column also tagged via DB schema metadata (e.g., AWS Glue/Azure Purview labels) — emit with `confidence=0.9`.
4. **Inferred via call graph:** field is read by a method that already has a `CARRIES_PHI` outgoing edge — propagate with degraded confidence (multiply by 0.8 per hop).

### Edges
- `CARRIES_PHI` (symbol → phi_field): "this method touches PHI"
- `LEAKS_PHI_TO` (carries_phi method → sink): sink = log writer, HTTP response without auth attribute, file write, external HTTP client, queue producer
- Negative edge: `SANITIZED_BY` (phi → redactor function) — clears the taint downstream

### Gates this enables (advisory at v1)
- Endpoint that `CARRIES_PHI` but lacks `[Authorize]` attribute
- Method that `LEAKS_PHI_TO` log without going through known redactor
- New PHI field added without `[PhiField]` annotation (regex-detected, attribute-missing)

These overlap with the existing `phi_redactor.py` test that's flagged in `CLAUDE.md` known issues — the KG would prevent that drift from happening again.

**Honest precision at v1: ~0.40.** Most flags will be near-misses. Ship as advisory diff comments, not blocking gates, until calibrated against real PRs.

---

## 10. Gotchas (the things that will actually break)

| # | Gotcha | Mitigation |
|---|---|---|
| **1** | **KG drift** — KG says `Foo.Bar()` exists; merge SHA already deleted it | Every query result includes `extracted_at_sha`; if older than `HEAD` by >N commits, force refresh. `meta.last_indexed_sha` is gospel. |
| **2** | **Tree-sitter ABI version mismatch** ("ABI too new: 14") | Pin `tree-sitter` and every `tree-sitter-<lang>` to compatible majors in `pyproject.toml`. Run `tree-sitter --version` check on startup. ([ABI issue](https://github.com/tree-sitter/tree-sitter/issues/3925)) |
| **3** | **Razor edge cases** — generic Razor with embedded C# blocks parsing wrong | Document partial Razor support; emit `tag.scm` failures with `confidence=0.3` so they're visible but not load-bearing. |
| **4** | **C# 12 primary constructors on records** — known parse error in tree-sitter-c-sharp ([issue 329](https://github.com/tree-sitter/tree-sitter-c-sharp/issues/329)) | Detect `ERROR` nodes in the parsed tree; fall back to regex-extract for affected files. Track parse-failure rate as `meta.parse_health`. |
| **5** | **DuckDB VSS persistence corruption on crash** | Don't persist HNSW indexes. Rebuild on startup from persistent embedding table. Acceptable for ~50k vectors (sub-second). ([VSS docs](https://duckdb.org/docs/current/core_extensions/vss)) |
| **6** | **DuckDB FTS doesn't update incrementally** | Drop+recreate on a debounce; mark KG `fts_dirty=true` between rebuilds; queries that hit FTS during a dirty window fall back to LIKE+regex. |
| **7** | **Cross-language calls** (TS `fetch('/api/x')` → C# `[Route("api/x")]`) | Match by string normalization (lowercased, parameter-stripped path). Mark these edges `confidence=0.6` and `source_method='cross_lang_string_match'`. Stack-graphs would do better but is out of scope for v1. |
| **8** | **Monorepo size** — 100k+ files | DuckDB handles 10M-row tables fine; FTS at that scale becomes the bottleneck. Strategy: shard FTS by language, pre-filter by file path before FTS. |
| **9** | **Schema evolution** — we will rev this schema | `meta(key, value)` table with `schema_version`. Migration scripts under `tools/kg-migrations/<n>__description.sql`. Refuse to query if version mismatch. |
| **10** | **Worktree contamination** — a make-bolt run on epic A reads stale KG built on epic B's branch | Each worktree gets its own scratch KG built from its own merge-base. Canonical KG is read-only from a worktree's perspective unless we're in the merge-serial phase. |
| **11** | **Hash collisions on edge dedup** — using `(src_id, dst_id, edge_type)` as PK can collide for repeated calls in the same method | Add `call_site_offset INTEGER` (byte offset) to PK for `CALLS` edges. |
| **12** | **PHI false positives swamp signal** | All PHI gates are advisory at v1, surfaced in PR comments, never blocking. Calibrate from real PR data before promoting. |

---

## Concrete DuckDB schema (CREATE TABLE statements)

Designed for: incremental update by `(file_path, content_hash)`, fast neighbor queries via columnar scans + indexes on `src_symbol_id`/`dst_symbol_id`, FTS on names/docstrings, optional embeddings via VSS, JSON for grab-bag attributes.

```sql
-- =============================================================================
-- KG SCHEMA v1 — make-bolt + run-bolt
-- =============================================================================
PRAGMA enable_object_cache;
INSTALL fts;  LOAD fts;
INSTALL vss;  LOAD vss;
INSTALL json; LOAD json;

-- -- META --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meta (
    key          VARCHAR PRIMARY KEY,
    value        VARCHAR,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Seed: schema_version, last_indexed_sha, parse_health, fts_dirty, embedding_model

-- -- COMMITS ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS commits (
    commit_sha   VARCHAR PRIMARY KEY,
    parent_sha   VARCHAR,
    author       VARCHAR,
    committed_at TIMESTAMP,
    message      VARCHAR
);

-- -- FILES ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS files (
    file_id        BIGINT PRIMARY KEY,           -- xxh3_64(repo_relative_path)
    repo_path      VARCHAR NOT NULL UNIQUE,
    language       VARCHAR NOT NULL,             -- csharp|typescript|tsx|html|scss|sql|razor|...
    content_hash   VARCHAR NOT NULL,             -- xxh3_64 of bytes
    size_bytes     INTEGER,
    line_count     INTEGER,
    parse_status   VARCHAR NOT NULL,             -- ok|partial|error
    parse_errors   INTEGER DEFAULT 0,
    first_seen_sha VARCHAR,
    last_seen_sha  VARCHAR,
    last_parsed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    attributes     JSON
);
CREATE INDEX IF NOT EXISTS idx_files_lang ON files(language);
CREATE INDEX IF NOT EXISTS idx_files_hash ON files(content_hash);

-- -- SYMBOLS ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS symbols (
    symbol_id      VARCHAR PRIMARY KEY,          -- SCIP-style: scheme manager pkg version desc
    file_id        BIGINT NOT NULL REFERENCES files(file_id),
    kind           VARCHAR NOT NULL,             -- namespace|class|interface|record|struct|enum|method|function|property|field|constructor|component|hook|controller|endpoint|db_entity|...
    name           VARCHAR NOT NULL,
    qualified_name VARCHAR NOT NULL,             -- e.g. the project.Services.Auth.LoginHandler.Execute
    parent_symbol  VARCHAR,                      -- nullable; FK soft-ref to symbols.symbol_id
    visibility     VARCHAR,                      -- public|private|internal|protected
    is_static      BOOLEAN DEFAULT FALSE,
    is_async       BOOLEAN DEFAULT FALSE,
    is_test        BOOLEAN DEFAULT FALSE,
    signature      VARCHAR,                      -- params + return for callables
    docstring      VARCHAR,                      -- xml-doc, jsdoc, etc
    start_line     INTEGER NOT NULL,
    end_line       INTEGER NOT NULL,
    start_byte     INTEGER NOT NULL,
    end_byte       INTEGER NOT NULL,
    extracted_at_sha VARCHAR,
    attributes     JSON                          -- attrs/decorators, source-gen markers, etc
);
CREATE INDEX IF NOT EXISTS idx_symbols_file ON symbols(file_id);
CREATE INDEX IF NOT EXISTS idx_symbols_kind ON symbols(kind);
CREATE INDEX IF NOT EXISTS idx_symbols_qname ON symbols(qualified_name);
CREATE INDEX IF NOT EXISTS idx_symbols_parent ON symbols(parent_symbol);

-- -- EDGES (call/ref/inherit/import/etc) ------------------------------------
CREATE TABLE IF NOT EXISTS edges (
    edge_id        BIGINT PRIMARY KEY,            -- monotonic
    src_symbol_id  VARCHAR NOT NULL,
    dst_symbol_id  VARCHAR,                       -- nullable for unresolved refs
    dst_unresolved VARCHAR,                       -- raw target string when dst is unresolved
    edge_type      VARCHAR NOT NULL,              -- CALLS|OVERRIDES|IMPLEMENTS|INHERITS|CONTAINS|REFERENCES|IMPORTS|USES_TYPE|THROWS|READS|WRITES|TESTS|ROUTES_TO|FE_CALLS_BE|MAPS_TO_TABLE|MIGRATED_BY|OWNS|AFFECTS|CARRIES_PHI|LEAKS_PHI_TO|SANITIZED_BY
    confidence     FLOAT NOT NULL,                -- 0.0..1.0
    source_method  VARCHAR NOT NULL,              -- ts_query|regex|cross_lang_string|llm_inferred|attribute|migration_diff
    call_site_offset INTEGER,                     -- byte offset disambiguator for repeated edges
    first_seen_sha VARCHAR,
    last_seen_sha  VARCHAR,
    attributes     JSON
);
CREATE INDEX IF NOT EXISTS idx_edges_src ON edges(src_symbol_id, edge_type);
CREATE INDEX IF NOT EXISTS idx_edges_dst ON edges(dst_symbol_id, edge_type);
CREATE INDEX IF NOT EXISTS idx_edges_type ON edges(edge_type);
CREATE INDEX IF NOT EXISTS idx_edges_unresolved ON edges(dst_unresolved) WHERE dst_unresolved IS NOT NULL;

-- -- HTTP ENDPOINTS (cross-language matching anchor) ------------------------
CREATE TABLE IF NOT EXISTS http_endpoints (
    endpoint_id     BIGINT PRIMARY KEY,
    handler_symbol  VARCHAR NOT NULL REFERENCES symbols(symbol_id),
    http_method     VARCHAR NOT NULL,             -- GET|POST|PUT|DELETE|PATCH|...
    path_template   VARCHAR NOT NULL,             -- /api/v1/users/{id}
    path_normalized VARCHAR NOT NULL,             -- /api/v1/users/* — for FE matching
    has_authorize   BOOLEAN DEFAULT FALSE,
    role_requirements VARCHAR,
    attributes      JSON
);
CREATE INDEX IF NOT EXISTS idx_endpoints_path ON http_endpoints(path_normalized, http_method);

-- -- FRONTEND→BACKEND CALLSITES (preliminary, before resolve) ---------------
CREATE TABLE IF NOT EXISTS fe_be_callsites (
    callsite_id    BIGINT PRIMARY KEY,
    src_symbol_id  VARCHAR NOT NULL REFERENCES symbols(symbol_id),
    http_method    VARCHAR,                       -- nullable when inferred
    path_literal   VARCHAR NOT NULL,              -- raw '/api/x'
    path_normalized VARCHAR NOT NULL,
    resolved_endpoint_id BIGINT REFERENCES http_endpoints(endpoint_id),
    confidence     FLOAT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_febe_path ON fe_be_callsites(path_normalized, http_method);

-- -- DB SCHEMA NODES --------------------------------------------------------
CREATE TABLE IF NOT EXISTS db_tables (
    table_id      BIGINT PRIMARY KEY,
    schema_name   VARCHAR,
    table_name    VARCHAR NOT NULL,
    introduced_in_migration VARCHAR,
    attributes    JSON
);
CREATE TABLE IF NOT EXISTS db_columns (
    column_id     BIGINT PRIMARY KEY,
    table_id      BIGINT NOT NULL REFERENCES db_tables(table_id),
    column_name   VARCHAR NOT NULL,
    data_type     VARCHAR,
    is_pk         BOOLEAN DEFAULT FALSE,
    is_nullable   BOOLEAN DEFAULT TRUE,
    is_phi        BOOLEAN DEFAULT FALSE,
    phi_confidence FLOAT,
    attributes    JSON
);
CREATE INDEX IF NOT EXISTS idx_db_columns_table ON db_columns(table_id);
CREATE TABLE IF NOT EXISTS migrations (
    migration_id   VARCHAR PRIMARY KEY,
    name           VARCHAR,
    file_id        BIGINT REFERENCES files(file_id),
    applied_at_sha VARCHAR,
    operations     JSON                            -- [{op:CreateTable,...}, {op:AddColumn,...}]
);

-- -- TESTS COVERAGE ---------------------------------------------------------
-- Implemented as edges of type TESTS / TESTED_BY.

-- -- OWNERSHIP --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS code_owners (
    owner         VARCHAR NOT NULL,                -- @team or user
    glob          VARCHAR NOT NULL,
    rule_order    INTEGER NOT NULL,
    PRIMARY KEY (owner, glob)
);
-- File→owner mapping is computed lazily via OWNS edges.

-- -- ADRs / DOCS ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS docs (
    doc_id        BIGINT PRIMARY KEY,
    file_id       BIGINT NOT NULL REFERENCES files(file_id),
    kind          VARCHAR NOT NULL,                -- adr|readme|spec|claude_md|...
    title         VARCHAR,
    body          VARCHAR,
    front_matter  JSON
);

-- -- PHI TAGS ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS phi_tags (
    tag_id        BIGINT PRIMARY KEY,
    target_kind   VARCHAR NOT NULL,                -- symbol|column|endpoint
    target_id     VARCHAR NOT NULL,                -- symbol_id (str), column_id/endpoint_id (str-cast)
    source_method VARCHAR NOT NULL,                -- attribute|name_regex|propagated|annotation
    confidence    FLOAT NOT NULL,
    rationale     VARCHAR
);
CREATE INDEX IF NOT EXISTS idx_phi_target ON phi_tags(target_kind, target_id);

-- -- EMBEDDINGS (persistent table; HNSW index built in-memory at startup) ----
CREATE TABLE IF NOT EXISTS code_embeddings (
    symbol_id     VARCHAR PRIMARY KEY REFERENCES symbols(symbol_id),
    chunk_idx     INTEGER NOT NULL DEFAULT 0,      -- 0 = whole-symbol; >0 = sub-chunks
    model         VARCHAR NOT NULL,                -- text-embedding-3-large|bge-m3|...
    dim           INTEGER NOT NULL,
    vec           FLOAT[3072],                     -- adjust per model
    content_hash  VARCHAR NOT NULL,                -- of the embedded text — invalidate on change
    embedded_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- HNSW index: created at process startup over an in-memory copy.
-- CREATE INDEX hnsw_code_embeddings ON code_embeddings USING HNSW (vec) WITH (metric = 'cosine');

-- -- FTS (rebuilt on KG refresh) -------------------------------------------
-- After bulk symbol load:
-- PRAGMA create_fts_index('symbols', 'symbol_id', 'name', 'qualified_name', 'docstring',
--                         stemmer='english', stopwords='english_stopwords', overwrite=1);

-- -- AUDIT TRAIL -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS kg_runs (
    run_id        VARCHAR PRIMARY KEY,
    started_at    TIMESTAMP NOT NULL,
    finished_at   TIMESTAMP,
    triggered_by  VARCHAR NOT NULL,                -- make-bolt|run-bolt|manual|cron
    epic_slug     VARCHAR,
    ticket_id     VARCHAR,
    from_sha      VARCHAR,
    to_sha        VARCHAR NOT NULL,
    files_added   INTEGER,
    files_changed INTEGER,
    files_deleted INTEGER,
    symbols_added INTEGER,
    symbols_changed INTEGER,
    edges_added   INTEGER,
    edges_invalidated INTEGER,
    parse_failures INTEGER,
    duration_ms   INTEGER,
    notes         JSON
);
CREATE INDEX IF NOT EXISTS idx_kg_runs_to_sha ON kg_runs(to_sha);
```

### Example queries the schema is built for

```sql
-- 1. Callers of a symbol (Gate G3 — blast radius)
WITH RECURSIVE callers(sym, depth) AS (
    SELECT 'csharp::the project.Services.Auth.LoginHandler#Execute', 0
    UNION ALL
    SELECT e.src_symbol_id, c.depth + 1
    FROM edges e JOIN callers c ON e.dst_symbol_id = c.sym
    WHERE e.edge_type = 'CALLS' AND c.depth < 5
) SELECT sym, MIN(depth) AS shortest_path FROM callers GROUP BY sym;

-- 2. Scope drift (G1) — for a ticket touching files X, Y, Z
SELECT DISTINCT s2.file_id, f2.repo_path
FROM edges e
JOIN symbols s1 ON e.src_symbol_id = s1.symbol_id
JOIN symbols s2 ON e.dst_symbol_id = s2.symbol_id
JOIN files f1 ON s1.file_id = f1.file_id
JOIN files f2 ON s2.file_id = f2.file_id
WHERE f1.repo_path IN ('services/foo/X.cs', ...)
  AND f2.repo_path NOT LIKE 'services/foo/%';

-- 3. Dead code (G2) — new public methods with zero callers
SELECT s.symbol_id, s.qualified_name
FROM symbols s
LEFT JOIN edges e ON e.dst_symbol_id = s.symbol_id AND e.edge_type = 'CALLS'
WHERE s.kind IN ('method','function')
  AND s.visibility = 'public'
  AND s.first_seen_sha = (SELECT value FROM meta WHERE key = 'last_indexed_sha')
  AND e.edge_id IS NULL
  AND s.is_test = FALSE;

-- 4. FE→BE drift (G5) — FE calls without resolved endpoint
SELECT * FROM fe_be_callsites WHERE resolved_endpoint_id IS NULL;

-- 5. PHI propagation (G6) — endpoints carrying PHI without [Authorize]
SELECT he.path_template, he.http_method
FROM http_endpoints he
JOIN edges e ON e.src_symbol_id = he.handler_symbol AND e.edge_type = 'CARRIES_PHI'
WHERE he.has_authorize = FALSE;

-- 6. Semantic similar-code search (when embeddings present)
SELECT s.qualified_name, array_cosine_distance(ce.vec, ?::FLOAT[3072]) AS dist
FROM code_embeddings ce JOIN symbols s ON s.symbol_id = ce.symbol_id
ORDER BY dist ASC LIMIT 10;
```

---

## Summary recommendations (opinionated)

1. **Tree-sitter via py-tree-sitter, version-locked.** Skip bespoke Razor parsing — extract C# blocks via regex. Accept that ~5% of C# 12 records-with-primary-ctor parse with errors and emit `confidence=0.5` for symbols extracted from `parse_status='partial'` files.
2. **DuckDB single-file KG, in-memory VSS, FTS rebuilt on demand.** Don't take a hard dep on DuckPGQ or VSS persistence at v1.
3. **Incremental update via XXH3 + git diff + tree-sitter old-tree edits.** No salsa-style memoization — pay the per-commit reparse cost (single-digit seconds for 10k files).
4. **Symbol-level granularity for embeddings.** `text-embedding-3-large` default; `bge-m3` documented as air-gapped fallback for HIPAA tenants who can't egress.
5. **Ship gates G1, G2, G3, G4, G5, G7, G8, G10 at v1.** Defer G6 (PHI) to advisory and G9 (supersession) to v2.
6. **PHI tags via attribute > regex > propagation, all confidence-scored, all advisory.** Calibrate against real PR data before promoting to blocking.
7. **One canonical KG, worktree-local KGs as scratch.** Single-writer mainline, lock file. Schema-change tickets force full rebuild post-merge.
8. **Audit-branch artifact, source-rebuildable.** Don't pollute main with binary blobs.

This is the spec. Hand it to make-bolt + run-bolt design as the data-layer contract.

---

## Sources

- [tree-sitter/tree-sitter-c-sharp](https://github.com/tree-sitter/tree-sitter-c-sharp), [issue #329 primary constructors](https://github.com/tree-sitter/tree-sitter-c-sharp/issues/329), [issue #236 file-scoped types](https://github.com/tree-sitter/tree-sitter-c-sharp/issues/236), [PyPI 0.23.5](https://pypi.org/project/tree-sitter-c-sharp/)
- [tree-sitter/tree-sitter-typescript](https://github.com/tree-sitter/tree-sitter-typescript), [npm](https://www.npmjs.com/package/tree-sitter-typescript), [Snyk](https://snyk.io/advisor/python/tree-sitter-typescript)
- [tree-sitter/tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript), [tree-sitter/tree-sitter-html](https://github.com/tree-sitter/tree-sitter-html)
- [tree-sitter-grammars (org)](https://github.com/tree-sitter-grammars), [tris203/tree-sitter-razor](https://github.com/tris203/tree-sitter-razor), [swimmio/tree-sitter-razor-csharp](https://github.com/swimmio/tree-sitter-razor-csharp), [tree-sitter/tree-sitter-razor (WIP)](https://github.com/tree-sitter/tree-sitter-razor)
- [DerekStride/tree-sitter-sql](https://github.com/DerekStride/tree-sitter-sql), [releases](https://github.com/DerekStride/tree-sitter-sql/releases)
- [py-tree-sitter docs](https://tree-sitter.github.io/py-tree-sitter/), [tree-sitter (parser library)](https://github.com/tree-sitter/tree-sitter), [Strumenta on incremental parsing](https://tomassetti.me/incremental-parsing-using-tree-sitter/), [ABI version issue 3925](https://github.com/tree-sitter/tree-sitter/issues/3925), [TIL py-tree-sitter](https://til.simonwillison.net/python/tree-sitter)
- [tree-sitter/tree-sitter-graph](https://github.com/tree-sitter/tree-sitter-graph)
- [Aider repo map blog](https://aider.chat/2023/10/22/repomap.html), [aider/repomap.py](https://github.com/Aider-AI/aider/blob/main/aider/repomap.py), [DeepWiki repomap](https://deepwiki.com/Aider-AI/aider/4.1-repository-mapping)
- [Codebase-Memory paper (arxiv 2603.27277)](https://arxiv.org/html/2603.27277v1)
- [code-review-graph](https://github.com/tirth8205/code-review-graph)
- [Sourcegraph SCIP announcement](https://sourcegraph.com/blog/announcing-scip), [SCIP repo](https://github.com/sourcegraph/scip), [scip-dotnet](https://github.com/sourcegraph/scip-dotnet), [scip-dotnet releases](https://github.com/sourcegraph/scip-dotnet/releases), [Sourcegraph indexers list](https://sourcegraph.com/docs/code-search/code-navigation/writing_an_indexer)
- [GitHub stack-graphs blog](https://github.blog/open-source/introducing-stack-graphs/), [stack-graphs paper (arxiv 2211.01224)](https://arxiv.org/pdf/2211.01224), [stack-graphs repo](https://github.com/github/stack-graphs)
- [Glean (Meta)](https://github.com/facebookincubator/Glean), [Meta engineering blog on Glean](https://engineering.fb.com/2024/12/19/developer-tools/glean-open-source-code-indexing/), [HN discussion](https://news.ycombinator.com/item?id=42568516)
- [Joern docs](https://docs.joern.io/), [Code Property Graph spec](https://cpg.joern.io/), [ShiftLeft codepropertygraph](https://github.com/ShiftLeftSecurity/codepropertygraph)
- [CodeQL overview](https://codeql.github.com/docs/codeql-overview/about-codeql/), [CodeQL home](https://codeql.github.com/), [CodeQL cpp dbscheme example](https://github.com/github/codeql/blob/main/cpp/ql/lib/semmlecode.cpp.dbscheme)
- [DuckDB FTS docs](https://duckdb.org/docs/current/core_extensions/full_text_search.html), [DuckDB text analytics 2025](https://duckdb.org/2025/06/13/text-analytics)
- [DuckDB VSS docs](https://duckdb.org/docs/current/core_extensions/vss), [DuckDB VSS announcement](https://duckdb.org/2024/05/03/vector-similarity-search-vss), [duckdb-vss repo](https://github.com/duckdb/duckdb-vss)
- [DuckDB JSON](https://duckdb.org/docs/current/data/json/overview.html)
- [DuckPGQ](https://duckpgq.org/), [DuckPGQ property graph syntax](https://duckpgq.org/documentation/property_graph/), [DuckPGQ extension repo](https://github.com/cwida/duckpgq-extension), [DuckDB graph queries guide](https://duckdb.org/docs/current/guides/sql_features/graph_queries)
- [DuckDB USING KEY recursive CTE blog](https://duckdb.org/2025/05/23/using-key), [SIGMOD paper on USING KEY](https://duckdb.org/science/bamberg-using-key-sigmod/)
- [rust-analyzer durable incrementality](https://rust-analyzer.github.io/blog/2023/07/24/durable-incrementality.html), [rustc-dev-guide salsa](https://rustc-dev-guide.rust-lang.org/queries/salsa.html)
- [BAAI/bge-m3 on Hugging Face](https://huggingface.co/BAAI/bge-m3), [MTEB benchmark](https://github.com/embeddings-benchmark/mteb), [RAG chunking benchmark guide](https://nandigamharikrishna.substack.com/p/rag-chunking-strategies-and-embeddings)
- [HIPAA-compliant AI coding (Augment)](https://www.augmentcode.com/guides/hipaa-compliant-ai-coding-guide-for-healthcare-developers), [Static analysis tools 2026](https://dev.to/rahulxsingh/static-code-analysis-tools-the-definitive-guide-2026-19cg), [CodeQL meaning + use cases](https://devsecopsschool.com/blog/codeql/)
- [hmarr/codeowners](https://github.com/hmarr/codeowners), [codeowners.org](https://codeowners.org/)
- [ASP.NET Core routing docs](https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/routing?view=aspnetcore-10.0), [Roslyn analyzer for ASP.NET Core (DotNetAnalyzers)](https://github.com/DotNetAnalyzers/AspNetCoreAnalyzers), [PVS-Studio Roslyn analyzer guide](https://pvs-studio.com/en/blog/posts/csharp/0867/)
- [EF Core migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/)
- [Angular routes](https://angular.dev/guide/routing/define-routes), [Angular Route API](https://angular.dev/api/router/Route)
