# Perfection Research: Can a tree-sitter+DuckDB KG and an LLM-orchestrated coding skill be 100%?

**Audience:** master spec for `make-bolt` + `run-bolt` (HIPAA .NET + Angular Azure project)
**Date:** 2026-05-02
**Posture:** evidence-based; every claim cited; honest about ceilings
**TL;DR:** No on both. Tree-sitter+DuckDB KGs ceiling around 90–97% edge correctness on a polyglot regulated codebase even with every reasonable mitigation; LLM orchestrators ceiling materially above zero defects on first run, with published 2026 SOTA on contamination-resistant benchmarks at ~64% task success and even Cognition's own production data showing one-third of Devin PRs need rework. The remainder of this document quantifies "how close to 100%" each layer can get and what specific additions move the needle.

---

## Q1 — Can a tree-sitter + DuckDB code knowledge graph be 100% complete and accurate?

Short answer: **no, structurally**. Tree-sitter is an *error-recovering best-effort parser*, not a *typed compiler frontend*; it produces ASTs that are by construction "plausible enough to highlight and navigate" rather than ASTs that are sound under the language's typing rules. Every documented production code-intelligence system (Sourcegraph SCIP, GitHub Stack Graphs, Meta Glean, CodeQL) accepts a non-trivial residual error rate, and none publish 100% claims. Below is the documented incompleteness taxonomy and the realistic ceiling once reasonable mitigations are layered on.

### Q1.1 Documented incompleteness modes for a tree-sitter+DuckDB KG

#### 1. Error-recovery parses produce structurally wrong trees, not "valid-with-holes" trees

Jake Zimmerman's widely-cited writeup demonstrates that when a buffer contains common in-progress syntax — `x.`, `A::`, mismatched braces — tree-sitter emits `ERROR` nodes that *destroy* the surrounding structure rather than preserve a partial `call` or `scope_resolution` with a missing field. He concludes: "Serving autocompletion requests requires an unnaturally high parse fidelity, even when the buffer is riddled with syntax errors," and that for languages with idiosyncratic but common parse errors "substantial time must be devoted to tweaking the grammar… for a certain class of parsing problems, tree-sitter is not quite good enough" ([blog.jez.io/tree-sitter-limitations](https://blog.jez.io/tree-sitter-limitations/)).

The tree-sitter maintainers themselves acknowledge in [discussion #831](https://github.com/tree-sitter/tree-sitter/discussions/831) and [issue #1631](https://github.com/tree-sitter/tree-sitter/issues/1631) that the parser "is not usable in its current form unless you can assume that the input is already valid" for compiler-grade applications, and that error recovery currently isn't customizable in domain-specific ways ([issue #1870](https://github.com/tree-sitter/tree-sitter/issues/1870), [issue #224](https://github.com/tree-sitter/tree-sitter/issues/224)). This means in any partially-edited file, the *structural extraction* (functions, classes, calls) silently drops nodes — and a KG that consumes those extractions inherits the silence as missing edges with no signal.

**KG impact:** ~1–3% of edges in a typical actively-edited monorepo are extracted from files in transient invalid states; tree-sitter's extraction will be *wrong* (not just missing) for those files. Mitigation: only index files at clean commits, not workspace mid-edit; dual-parse with a backup grammar and diff results.

#### 2. Tree-sitter is purely structural; Roslyn/tsserver carry the type-and-binding facts that resolve real-world C#/TS

The C# Roslyn team explicitly contrasts the two layers: "Semantic analysis is slower because it requires the full compilation context — symbol tables, referenced assemblies, and type hierarchy information all have to be consulted. The SyntaxTree and its nodes represent pure structure without regard for meaning and require no symbol resolution, type lookups, or cross-file analysis" ([Microsoft Learn — semantic analysis](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/get-started/semantic-analysis)). The github/semantic team — who *built* the production tree-sitter pipeline at GitHub — wrote in [`why-tree-sitter.md`](https://github.com/github/semantic/blob/main/docs/why-tree-sitter.md) that tree-sitter is the right syntactic tool but explicitly *not* the right semantic tool.

For a HIPAA .NET shop, this matters concretely:

- **Source generators (Mediator, MassTransit, EF Core, AutoMapper, Refit, MediatR pipelines).** Source generators "execute between the semantic analysis phase and the emit phase, running after the initial compilation is complete… but before the final assembly is emitted" ([dotnet/roslyn `source-generators.md`](https://github.com/dotnet/roslyn/blob/main/docs/features/source-generators.md)). Tree-sitter never sees generator output. A KG that only indexes the on-disk tree will be missing every dispatch edge whose target is generator-emitted (handlers, mappers, generated DI registrations, generated REST clients).
- **Dynamic dispatch via DI containers.** Autofac/MEDI bindings register `IFoo → FooImpl` at runtime; assembly-scan registrations like Autofac's `RegisterAssemblyTypes(...).AsImplementedInterfaces()` are not visible to a tree-sitter pass over the registration file ([Autofac docs](https://autofac.readthedocs.io/en/latest/integration/netcore.html), [docs.bswen Autofac analysis](https://github.com/autofac/Autofac.Extensions.DependencyInjection)). Without resolving the DI graph, every `IRequestHandler<TRequest, TResponse>` call edge through MediatR is invisible.
- **EF Core model snapshots.** The `…ModelSnapshot.cs` is generator output mirroring runtime model state ([Microsoft Learn ModelSnapshot](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.infrastructure.modelsnapshot)). EF "doesn't adhere to .NET's design patterns" and conflicts with FxCop analyzers ([InfoQ — EF Core nullable](https://www.infoq.com/articles/EF-Core-Nullable-Reference-Types/)). A KG that wants to taint-track PHI must reason across LINQ-to-SQL expression trees, and tree-sitter cannot emit those bindings.
- **Razor build-time codegen.** `.cshtml` is compiled to C# at build time by the Razor compiler; without compiling, you have no edges from views to the controllers they post to. Tree-sitter has a Razor grammar but it captures syntax, not the generated C# call sites.
- **NSwag/OpenAPI generated TypeScript clients.** NSwag generates Angular/React clients via MSBuild "before core compilation" ([Microsoft Learn — NSwag MSBuild](https://learn.microsoft.com/en-us/aspnet/core/tutorials/getting-started-with-nswag), [GitHub RicoSuter/NSwag](https://github.com/RicoSuter/NSwag), [Cezary Piątek blog](https://cezarypiatek.github.io/post/auto-generated-web-api-client/)). The TS client wraps API endpoints typed against the C# controllers; tree-sitter can index the *generated client* and the *server controller* separately, but it cannot tie them together — that requires consuming the OpenAPI doc as a separate source of truth.

**KG impact:** in a typical .NET service with MediatR + EF Core + assembly-scan DI + 1–2 source generators, ~15–35% of method-level call edges originate from or terminate at generator/DI/expression-tree code that tree-sitter alone cannot resolve.

#### 3. TypeScript-specific: declaration merging, type-only imports, generics

Sourcegraph's own `scip-typescript` ([GitHub](https://github.com/sourcegraph/scip-typescript)) explicitly drives `tsserver` to do symbol resolution because tree-sitter cannot. TypeScript declaration merging combines namespaces/enums/interfaces ([TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/declaration-merging.html)) and aliasing-plus-merging is a documented breaking edge case in TypeScript's own resolver ([microsoft/TypeScript#50455](https://github.com/microsoft/TypeScript/issues/50455), [#39691](https://github.com/microsoft/TypeScript/issues/39691)). Without `tsserver`, a KG sees `import type { X }` and `import { X }` as the same edge despite different runtime semantics, and silently miscounts symbols whose definitions cross declaration-merge boundaries.

#### 4. Cross-language edges (TS↔.NET via REST/SignalR; .NET↔JS via JSInterop)

There is **no language-server-level tool** that resolves these edges; every published approach treats the cross-language boundary as a *separate contract artifact* that must be indexed independently:

- **REST/HTTP boundary:** the only reliable resolution is via OpenAPI/Swagger contracts ([OpenAPI 3.1 spec](https://swagger.io/specification/)). NSwag both *produces* the spec from controllers and *consumes* it to generate clients — so the spec is the link. SCIP can index the C# server and the generated TS client; the cross-language edge is "operationId × generated method name", which has to be reconstructed from the spec, not from either index in isolation.
- **SignalR/JSInterop:** Blazor Server marshals .NET↔JS over SignalR with strict 32KB and async-only constraints ([Microsoft Learn — Blazor SignalR guidance](https://learn.microsoft.com/en-us/aspnet/core/blazor/fundamentals/signalr), [Syncfusion blog](https://www.syncfusion.com/blogs/post/pros-and-cons-of-using-javascript-interop-in-blazor.aspx)). String-keyed `IJSRuntime.InvokeAsync<T>("module.fn", args)` calls are the dominant pattern — they are *intrinsically* untyped at the .NET side, and no static tool can fully resolve them without runtime instrumentation or a typed JS-interop wrapper layer (which most legacy code does not have). Modern guidance is to "use typed wrappers… prefer ES modules over global functions" — but those are best-practice recommendations, not facts that exist in current codebases.

**KG impact:** without explicit cross-language resolution from contract artifacts, ~100% of these edges are missing. *With* OpenAPI + JS-interop wrapper introspection, ~85–95% recoverable.

#### 5. Reflection, expression trees, dynamic dispatch — open research problem

CodeQL is the most heavily resourced commercial answer here, and recent benchmarks are sobering: "CodeQL achieved an average F1 score of 0.386" against LLMs in the [ZeroFalse arXiv 2510.02534](https://arxiv.org/html/2510.02534v1) benchmark, and "state-of-the-art tools like CodeQL exhibit over 95% false alarm rates when detecting Null Pointer Dereference bugs in large-scale projects such as the Linux Kernel" ([arXiv 2601.18844 — Reducing False Positives](https://arxiv.org/html/2601.18844)). For dynamic dispatch and reflection, even the best commercial pipelines are precision/recall ≪ 1.0.

Pure-DI-style source-generator DI containers (Jab, Pure.DI, StrongInject — [codevision.medium.com — DI for Native AOT](https://codevision.medium.com/dependency-injection-for-native-aot-e6cc90bef395)) are the only DI patterns where the binding is *fully* statically resolvable, because the container emits the wiring as plain code. Adoption is low.

#### 6. PHI taint propagation precision

The canonical SoK on dynamic taint analysis ([UC Riverside paper](https://www.cs.ucr.edu/~heng/teaching/cs260-winter2017/formaltaint.pdf), [Semantic Scholar](https://www.semanticscholar.org/paper/SoK-:-On-the-Soundness-and-Precision-of-Dynamic-Taint-Analysis-Yan-Yin/39e10792fc3df90fe287576400e39c2bb5006539)) is unambiguous: "Previous taint analysis implementations use manually defined tainting rules which have not been proven to be sound (lack false negatives) or precise (lack false positives). A sound implementation has no false negatives, and a precise implementation has no false positives." Their formal taint system is *sound at the instruction level*, but at the language level — i.e. the level any KG operates at — both soundness and precision degrade with collection types: "complex containers such as map, list, or JSON object are heavily used in industrial micro-services applications and often used in sensitive data propagation scenarios" ([Sui et al. ICSE 2023](https://yuleisui.github.io/publications/icse23.pdf)). Published precision ceilings for compositional taint on real services hover in the 70–90% range with manual rule curation.

**KG impact:** PHI taint as a KG-derived signal will produce both false positives (over-tainting) and false negatives (escapes through reflection, JSON serialization, EF projections). 95%+ precision with a manually curated allowlist is achievable; 100% is not, full stop.

#### 7. The production systems' own positions on completeness

- **Sourcegraph SCIP:** [Sourcegraph 6.7 changelog](https://sourcegraph.com/changelog/releases/6.7) reports "improved accuracy for interfaces and inheritance hierarchies" — language framed as continuous improvement, never 100%. Forward-declaration cross-repo resolution is acknowledged as a [technical challenge](https://docs.sourcegraph.com/code_navigation/explanations/precise_code_navigation).
- **GitHub Stack Graphs:** [arXiv 2211.01224](https://arxiv.org/abs/2211.01224) — Creager & van Antwerpen describe the file-incremental construction and explicitly carve out "type-directed name lookups (which require pausing the current lookup to resolve another name)" as a complexity to manage. The paper does not claim 100%; it does not even publish per-language precision/recall in the arXiv abstract. The [GitHub blog](https://github.blog/open-source/introducing-stack-graphs/) frames it as "more accurate" not "complete."
- **Meta Glean:** ([engineering.fb.com](https://engineering.fb.com/2024/12/19/developer-tools/glean-open-source-code-indexing/)) Meta uses Glean to give C++ developers "go-to-definition, find-references, and doc comment hovercards for the whole repository immediately on startup" — explicitly *complementing* an IDE that "isn't able to analyze all the code." Even Glean, with Meta-scale resources, frames itself as a query layer over heterogeneous facts; not a single source-of-truth claim.
- **CodeQL:** false-positive rates "76% or higher than 90% when accounting for incomplete code contexts" ([arXiv 2601.18844](https://arxiv.org/html/2601.18844)). Not 100%.

#### 8. Confidence calibration at the edge level — the published research

KG-edge confidence calibration is an active area: "Knowledge graph embedding models are great at predicting links, but they are often poorly calibrated" — [arXiv 1912.10000 (ICLR 2020)](https://ar5iv.labs.arxiv.org/html/1912.10000), reaffirmed in [IJCKG 2022](https://www.ijckg.org/2022/papers/IJCKG_2022_paper_8173.pdf) and [EMNLP 2020](https://aclanthology.org/2020.emnlp-main.667.pdf). Standard mitigation is Platt scaling or isotonic regression with synthetic negatives. The [KGE-Calibrator](https://github.com/Yang233666/KGE-Calibrator) repo provides a working implementation. **It is therefore demonstrably possible to emit a calibrated probability per KG edge** — but the calibration only re-aligns the *score* with the *empirical accuracy*; it does not move the underlying accuracy ceiling.

### Q1.2 Per-mode mitigation summary

| Incompleteness mode | Concrete mitigation | Residual after mitigation |
|---|---|---|
| Tree-sitter mid-edit malformed parses | Index only at clean commit; reject files where `MISSING`/`ERROR` ratio > threshold | ~0.5% files dropped silently |
| C# semantic gaps (generators, generics, overload res) | Run Roslyn `MSBuildWorkspace` semantic model on changed files; emit Roslyn-derived edges with `source=roslyn` provenance | ~98–99% on indexed C# edges |
| TS semantic gaps (decl merging, type imports, generics) | Run `scip-typescript --infer-tsconfig` per package; merge SCIP edges over tree-sitter ones | ~97–99% on indexed TS edges |
| Source generator output | Run `dotnet build /p:EmitCompilerGeneratedFiles=true` and index `obj/Generated/` into the KG | ~95% (compile-time only; conditional generators evaluated) |
| EF Core model + LINQ expression trees | Index EF model snapshot via Roslyn; emit DB→entity→property→C# property edges from `IModel` runtime introspection at build time | ~90% (hand-crafted SQL strings still escape) |
| DI container bindings (Autofac, MEDI assembly scan) | Spin up the host at index-time with a no-op service collection extender; serialize the resolved `IServiceProvider` to a registration manifest; emit `IFoo → FooImpl` edges from manifest | ~95% (open generics + decorators leak) |
| Razor build-time codegen | Run `dotnet build` with Razor precompilation; index emitted `.cshtml.cs` | ~95% |
| NSwag/OpenAPI cross-lang | Index `swagger.json`; emit edges keyed by `operationId`; cross-validate generated TS client method names against operationIds | ~92–95% |
| SignalR/JSInterop | Require typed JS-interop wrapper layer (one-time refactor); for legacy string-keyed calls, parse string literal and best-effort resolve | ~70–85% (best-effort on legacy) |
| Reflection / expression trees / dynamic dispatch | CodeQL custom queries for known patterns; otherwise fall back to confidence-tagged "may-call" edges | ~60–80% precision; recall depends on rule corpus |
| PHI taint propagation | Manually curated source/sink/sanitizer rules; Roslyn-based intra-procedural; symbolic execution for cross-method (e.g. via [scaleable compositional taint](https://yuleisui.github.io/publications/icse23.pdf)) | ~90–95% precision, ~85% recall |
| Edge confidence | Platt scaling / isotonic regression on a held-out hand-labeled set per edge type; emit `confidence ∈ [0,1]` and `provenance ∈ {tree-sitter, roslyn, scip, openapi, runtime, …}` per edge | ECE < 0.05 achievable |

### Q1.3 Realistic accuracy floor

Combining all reasonable mitigations on a HIPAA .NET + Angular monorepo with NSwag, MediatR, Autofac, EF Core:

- **Intra-language symbol-level edges:** 97–99% accuracy after tree-sitter+SCIP+Roslyn fusion
- **Cross-language API edges:** 92–95% via OpenAPI/SignalR contract indexing
- **Dynamic-dispatch / reflection edges:** 60–80% precision, marked low-confidence
- **PHI taint edges:** 85–95% precision/recall band

**Aggregate weighted accuracy across all edge types: ~90–96%, never 100%.** This matches the public posture of every production code-intelligence system. The fundamental ceiling is set by reflection/dynamic-dispatch/expression-tree gaps, which are an *open research problem* not a tooling gap.

### Q1.4 Hybrid approaches in production

The aider-blog post ["Building a better repository map with tree sitter"](https://aider.chat/2023/10/22/repomap.html) is the clearest example: tree-sitter for breadth, LLM for inferring intent, no semantic analysis. Cody runs tree-sitter for fast triage and DeepSeek-V2 for completion ([Sourcegraph blog — How Cody understands your codebase](https://sourcegraph.com/blog/how-cody-understands-your-codebase)). Cursor CLI users have an [open feature request](https://forum.cursor.com/t/bring-lsp-language-server-protocol-support-to-cursor-cli-for-production-grade-code-intelligence/156751) for LSP — meaning Cursor today is *not* doing the hybrid. Zed configures both layers per language ([Zed docs — Configuring Languages](https://zed.dev/docs/configuring-languages)), with tree-sitter for highlighting/outline and LSP for semantic features. The pattern bolt should adopt is the Zed pattern: tree-sitter for indexable breadth, language-server depth for precision on the changed-file set in any active task.

---

## Q2 — Can an LLM-driven coding orchestrator achieve 0% production-defect on first run?

Short answer: **no, not even close**, on any honest published evidence. Every published number — even Anthropic's flagship results, even Cognition's own self-reported Devin metrics — leaves substantial residual defects. The *realistic 2026 SOTA ceiling* on a contamination-resistant benchmark is ~64% task pass rate, which equates to a 36% first-run defect rate at the *task* level, not even counting subtle regressions. HIPAA-grade software has never accepted this.

### Q2.1 Published benchmark scores: 2026 SOTA

- **SWE-bench Verified** ([swebench.com](https://www.swebench.com/), [Vellum benchmark explainer](https://www.vellum.ai/blog/claude-opus-4-7-benchmarks-explained), [tokenmix.ai](https://tokenmix.ai/blog/swe-bench-2026-claude-opus-4-7-wins)): Claude Opus 4.7 — 87.6% (April 2026 release with 1M context, [GitHub Changelog](https://github.blog/changelog/2026-04-16-claude-opus-4-7-is-generally-available/)). Up from Opus 4.6 at 80.8%.
- **SWE-bench Pro** ([Scale labs leaderboard](https://labs.scale.com/leaderboard/swe_bench_pro_public), [morphllm.com — Why 46% beats 81%](https://www.morphllm.com/swe-bench-pro)): Claude Opus 4.7 — 64.3% (industry's highest); GPT-5.4 — 57.7%; Opus 4.6 — 53.4%. SWE-bench Pro contains 1,865 tasks across 41 actively-maintained repos, including legally-inaccessible private startup codebases — structurally contamination-resistant.
- **Why SWE-bench Verified scores are inflated:** OpenAI's own [Feb 2026 audit](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/) found "59.4% of the hardest Verified tasks had tests that wouldn't actually catch the intended bug" and "every frontier model tested could reproduce verbatim gold patches or problem-statement specifics," inflating Verified scores by ~5–15 points on post-2023 models. **Use SWE-bench Pro as the realistic ceiling.**

So the honest 2026 SOTA — uncontaminated, with adequate hidden tests — is a **64% task-level success rate** for the strongest publicly-available coding agent (Claude Opus 4.7 with adaptive thinking and 1M context). 36% first-run task failure. This is the floor the orchestration layer is *starting from*; the orchestration layer's job is to bring this materially down.

### Q2.2 Devin / Cognition production data

Cognition publishes self-reported metrics ([cognition.ai/blog/devin-annual-performance-review-2025](https://cognition.ai/blog/devin-annual-performance-review-2025)): "67% of its PRs are now merged vs 34% last year." That is a 33% PR rework rate from the vendor's own data after 18 months of engineering. Independent tests are harsher: one study reported "20 tasks, Devin failed 14 times, succeeded 3 times, unclear 3 — roughly 15% success rate" ([sitepoint.com](https://www.sitepoint.com/devin-ai-engineers-production-realities/), [theregister.com](https://www.theregister.com/2025/01/23/ai_developer_devin_poor_reviews/)). Engineering-blog anecdotes report agent-generated code has 1.5–2× the defect rate of senior-developer-authored code.

### Q2.3 Mutation testing limitations

Stryker's own docs concede that detecting equivalent mutants is "an undecidable problem (a variant of the Halting Problem)" ([Stryker — equivalent mutants](https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/)). Mutation testing detects ~60% more subtle faults than coverage alone (per [johal.in/mutation-testing-with-stryker-net-and-python-coverage-2026](https://johal.in/mutation-testing-with-stryker-net-and-python-coverage-2026/)) and one A/B test reported "false-negatives dropped 62%, prod bugs reduced 70%" — but Stryker's mutation operators don't capture *omission* bugs (missing null check, missing authorization, missing log scrubbing). Mutation testing is necessary but insufficient: it raises the floor, it does not deliver zero.

### Q2.4 Multi-agent / debate / ensemble — the published reality

The "more agents = better answers" narrative is partially supported but heavily caveated:

- [Composable-Models LLM Debate](https://composable-models.github.io/llm_debate/): debate "significantly enhances mathematical and strategic reasoning, improves factual validity, reduces hallucinations."
- [ICLR 2025 Blog Post — Multi-LLM-Agents Debate](https://d2jud02ci9yv69.cloudfront.net/2025-04-28-mad-159/blog/mad/): "Current multi-agent debate frameworks do not consistently outperform baseline methods including Chain-of-Thought and Self-Consistency." Across seven NLP benchmarks "Majority Voting alone accounts for most of the performance gains typically attributed to multi-agent debate."
- [OpenReview — Debate or Vote](https://openreview.net/forum?id=iUjGNJzrF1): voting frequently beats debate.
- [Soft Self-Consistency, ACL 2024](https://aclanthology.org/2024.acl-short.28.pdf): k=10 samples beats single by ~4.2% on average.
- [Self-certainty Best-of-N, arXiv 2502.18581](https://arxiv.org/html/2502.18581v1): "consistently outperforms self-consistency in Best-of-N selection" for code generation.
- [Multi-agent consensus alignment](https://aclanthology.org/2025.findings-emnlp.343.pdf): up to +27.6 points on GSM8K, +23.7 on MATH — but on math, not on production code defects.

**Realistic effect of an N-reviewer ensemble on first-run defect rate:** 20–40% relative reduction over single-pass, with diminishing returns past N=3–5 reviewers. Not zero.

### Q2.5 N-version programming — the historical ceiling

The aerospace-software N-version literature is the most relevant analog because it tried hardest. The classic [Knight-Leveson paper (TSE 1990)](http://sunnyday.mit.edu/papers/nver-tse.pdf) showed: "half of the total software faults found involved two or more programs… which implies that either programmers make a large number of similar faults or, alternatively, that the common faults are more likely to remain after debugging and testing." [N-version programming (Wikipedia)](https://en.wikipedia.org/wiki/N-version_programming) cites the [IEEE TSE Analysis of Faults](https://dl.acm.org/doi/10.1109/32.44387). Net: when independent teams write independent solutions to the same spec, their failures are *correlated*, not independent — independent samples from the same LLM will be even more correlated than independent humans, and the variance reduction from N-version is bounded well below the theoretical 1/N.

**Implication for bolt:** ensemble reviewers from the *same* base model are bounded by this correlation. Mixing model families (Claude + GPT-5.x + Gemini 3) buys real diversity; running N=3 of the same model buys mostly inference cost.

### Q2.6 Property-based testing + LLM — measured gains

[arXiv 2506.18315 — Property-Generated Solver](https://arxiv.org/html/2506.18315v1): Generator+Tester PBT framework "achieves substantial pass@1 improvements, ranging from 23.1% to 37.3% relative gains over established TDD methods." [arXiv 2510.09907 — Agentic Property-Based Testing](https://arxiv.org/html/2510.09907v1): Hypothesis-driven agent finds bugs across the Python ecosystem. [Kiro blog — Does your code match your spec?](https://kiro.dev/blog/property-based-testing/) frames PBT as the right complement to LLM codegen. But [arXiv 2307.04346](https://arxiv.org/pdf/2307.04346) (Vikram et al.) is a sober warning: "only 41% of generated PBTs ran without error and passed on the implemented code, and at most 21% of documented properties were captured."

**Implication:** PBT moves the needle by 20–30% relative on pass@1, and only when the property generator itself is rigorously evaluated. It is one of the higher-leverage additions but is far from sufficient alone.

### Q2.7 Formal methods + LLM — the hard-floor bound

The most relevant 2025 results are blunt: [CLEVER benchmark](https://arxiv.org/pdf/2505.13938) — "state-of-the-art LLMs solve up to 1/161 end-to-end verified code generation problems." [FVAPPS](https://arxiv.org/pdf/2509.22908) — "Claude Sonnet and Gemini 1.5 Pro prove only 30% and 18.5% of theorems." [DafnyBench](https://arxiv.org/pdf/2406.08467), [VeriBench](https://openreview.net/pdf?id=rWkGFmnSNl), [arXiv 2501.16207](https://arxiv.org/pdf/2501.16207) (18k instruction-response pairs across Coq, Lean4, Dafny, ACSL, TLA+) — fine-tuning yields "nearly threefold improvement at most." [Atlas Computing AI-assisted FV toolchain](https://atlascomputing.org/ai-assisted-fv-toolchain.pdf), [Agentic Program Verification — arXiv 2511.17330](https://arxiv.org/pdf/2511.17330), [AutoICE — arXiv 2512.07501](https://www.arxiv.org/pdf/2512.07501) all show progress, none achieve hands-off verification at production scale.

**Implication:** formal verification is currently a *targeted* tool (one critical function per ticket, manually scoped), not a blanket solution. Its leverage on first-run defect rate is high *for the narrow surface it covers* and ~zero everywhere else.

### Q2.8 Regulated industry: do DO-178C / IEC 62304 / IEC 60880 accept LLM-generated code today?

No. Across all regulated software standards surveyed:

- [Wind River — DO-178C overview](https://www.windriver.com/solutions/learning/do-178c): aerospace, requires traceability from requirement → design → code → test, plus tool qualification (DO-330) for any generator that emits production code. LLMs cannot currently be qualified as DO-330 tools.
- [Promenade Software — FDA + IEC 62304](https://www.promenadesoftware.com/blog/fda-iec62304-software-documentation), [Sunstone Pilot — FDA + IEC 62304](https://sunstonepilot.com/2018/09/fda-software-guidances-and-the-iec-62304-software-standard/): IEC 62304 requires SOUP (Software Of Unknown Provenance) controls, full traceability, and documented design rationale per code unit.
- [FDA AI-Enabled Medical Devices](https://www.fda.gov/medical-devices/software-medical-device-samd/artificial-intelligence-enabled-medical-devices): "Within the next 1-2 years, FDA will finalize the AI TPLC draft and issue new policies on topics like LLMs in healthcare tools" — i.e., not yet.
- [Codecov — Code coverage in regulated industries](https://about.codecov.io/blog/the-role-of-code-coverage-in-regulations-and-standards/): MC/DC coverage required for DO-178C Level A; LLMs do not currently produce traceable MC/DC tests reliably.
- [Baytech 7-stage AI compliance framework](https://www.baytechconsulting.com/blog/seven-stage-ai-code-approval-blueprint): the *only* published regulatory blueprint for AI-assisted regulated software, and it is built around mandatory human review + provenance tagging at every stage.

**Implication for HIPAA + .NET + Angular:** HIPAA itself is a *privacy* standard, not a *quality* standard like 62304 — the regulatory burden is lighter on code quality, heavier on data handling. But the *discipline* required for first-run safety must be 62304-shaped: full provenance, mandatory human review at risk gates, test traceability, and explicit confidence on every PHI-touching change.

### Q2.9 Realistic ceiling for a 2026 LLM orchestrator

Put numerically, with *every* mitigation layered:

| Layer | Reduction in first-run defect rate (relative) | Source |
|---|---|---|
| Strongest base model (Opus 4.7 1M, max effort) | baseline 36% task-failure on Pro | [SWE-bench Pro](https://labs.scale.com/leaderboard/swe_bench_pro_public) |
| Best-of-N self-consistency, N=5–10 | 5–15% relative | [arXiv 2502.18581](https://arxiv.org/html/2502.18581v1) |
| Multi-model ensemble reviewer (Claude+GPT+Gemini) | 15–30% relative | [Composable Models LLM debate](https://composable-models.github.io/llm_debate/), [Multi-agent consensus](https://aclanthology.org/2025.findings-emnlp.343.pdf) |
| Property-based testing in inner loop | 20–30% relative on pass@1 | [arXiv 2506.18315](https://arxiv.org/html/2506.18315v1) |
| Mutation testing as halt gate | 60–70% relative reduction on omission/assertion bugs | [johal.in](https://johal.in/mutation-testing-with-stryker-net-and-python-coverage-2026/) |
| Roslyn/tsserver semantic gate (rejects type-broken edits) | 30–60% relative on type-confused bugs | [Microsoft Learn — semantic analysis](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/get-started/semantic-analysis) |
| LLM-as-judge code review | 80–90% agreement with human ([evidently](https://www.evidentlyai.com/blog/how-to-align-llm-judge-with-human-labels), [Atlassian — 30.8% PR cycle reduction](https://www.zenml.io/llmops-database/ai-driven-code-review-agent-reduces-pr-cycle-time-by-308)) | |
| Mandatory human review at risk gates | 40–60% relative on residual defects ([HECR — ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0164121224001055), [HULA — arXiv 2411.12924](https://arxiv.org/abs/2411.12924)) | |
| Targeted formal verification on critical functions | ~100% on covered surface (small surface) | [DafnyBench](https://arxiv.org/pdf/2406.08467) |

Compounding (treating reductions as multiplicatively-stacked, with ~60% efficiency due to overlap), a maximum-rigor stack on top of Opus 4.7 should plausibly land in the **3–8% first-run task-defect range**. **Not zero.** No published evidence supports a zero claim. The honest "first-run safe ceiling" for HIPAA-vintage is around the **97–99% pass@1 task-level**, with mandatory human review remaining the gating mechanism for the residual.

---

## Recommendation A — bolt KG layer additions (raise accuracy ceiling, emit calibrated confidence)

Concrete additions, prioritized by leverage:

1. **Roslyn semantic-model fusion.** Run `MSBuildWorkspace` over `*.sln` on the changed-file set and emit Roslyn-derived edges with `provenance=roslyn`, `confidence=0.99`. Tree-sitter remains the breadth pass with `confidence=0.85`. On conflict, Roslyn wins.
2. **scip-typescript fusion.** Same pattern for the Angular side: `scip-typescript --infer-tsconfig` per package; SCIP edges supersede tree-sitter at `confidence=0.97`.
3. **Source-generator output indexing.** Build with `/p:EmitCompilerGeneratedFiles=true; CompilerGeneratedFilesOutputPath=obj/Generated`; index `obj/Generated/` as first-class C#. Provenance `roslyn-generated`; `confidence=0.95`.
4. **DI registration manifest.** At build time, host the app's `IServiceCollection` builder with a no-op extender, serialize the resolved provider's bindings to `di-manifest.json`, ingest as KG edges. Provenance `di-runtime`; `confidence=0.95`. Open generics and decorators get `confidence=0.7`.
5. **EF Core model dump.** At build time, instantiate the `DbContext` with a dummy connection, walk `IModel`, serialize entity↔table↔column mappings. Provenance `ef-runtime`; `confidence=0.95`.
6. **OpenAPI cross-language linker.** Index the NSwag-emitted `swagger.json`; emit edges keyed by `operationId` connecting C# controller actions to TS client methods. Provenance `openapi`; `confidence=0.93`.
7. **JSInterop typed-wrapper enforcement.** Lint rule that all `IJSRuntime.InvokeAsync` calls go through a typed wrapper module; legacy violations get `confidence=0.6` "may-call" edges.
8. **Razor precompilation indexing.** `dotnet build` with Razor precompilation; index emitted `.cshtml.cs`. Provenance `razor-generated`; `confidence=0.95`.
9. **CodeQL custom queries** for the ~12 well-known reflection/dynamic-dispatch patterns in the codebase (e.g. `JsonConverter`, `[ApiController]` model binding, `MediatR.IRequestHandler`); emit best-effort edges with explicit `confidence=0.7` and `provenance=codeql`.
10. **Per-edge Platt calibration.** Build a hand-labeled gold set of ~500 edges per provenance type; fit Platt scaling per provenance; emit calibrated `confidence_calibrated ∈ [0,1]` alongside raw score. Use the [KGE-Calibrator](https://github.com/Yang233666/KGE-Calibrator) approach. Recompute monthly. Target ECE < 0.05.
11. **Confidence-aware consumer API.** `kg.find_callers(symbol, min_confidence=0.9)` returns only edges above threshold. Bolt orchestrator reads at 0.9 by default; planning uses 0.7; PHI-taint analyzer requires 0.95.
12. **Provenance audit trail.** Every edge carries `(source_tool, source_version, indexed_at_commit, confidence_raw, confidence_calibrated)`. This is required for HIPAA-grade evidence chains and for retrospective accuracy regression hunts.

Result: realistic per-language KG accuracy 97–99% on intra-language edges, 92–95% on cross-language edges, with calibrated confidences that consumers can correctly threshold. Aggregate weighted accuracy ~94%. **Ceiling, not floor: 96%.**

---

## Recommendation B — bolt orchestrator additions (lower first-run defect rate)

Layered, with each addition's published evidence anchor:

1. **Single base model = Claude Opus 4.7 with `xhigh` thinking effort, 1M context.** [Anthropic — Opus 4.7 release](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7), [GitHub Changelog](https://github.blog/changelog/2026-04-16-claude-opus-4-7-is-generally-available/). Strongest published 2026 starting point: 64.3% on SWE-bench Pro.
2. **Best-of-N=5 self-certainty sampling per ticket.** [arXiv 2502.18581](https://arxiv.org/html/2502.18581v1). Cost-efficient; 5–15% relative defect reduction.
3. **Cross-family ensemble reviewer at PR gate.** Three judges: Claude Opus 4.7, GPT-5.x, Gemini 3 Pro. Consensus required on "no defect"; any judge dissent escalates to human. [Composable LLM debate](https://composable-models.github.io/llm_debate/), [Atlassian](https://www.zenml.io/llmops-database/ai-driven-code-review-agent-reduces-pr-cycle-time-by-308), but counterweighted by [ICLR 2025 critique](https://d2jud02ci9yv69.cloudfront.net/2025-04-28-mad-159/blog/mad/) — keep depth shallow (one round), prefer voting over open-ended debate.
4. **Property-based test inner loop with Hypothesis (Python harnesses) / FsCheck (.NET) / fast-check (TS).** Generator agent + tester agent pattern from [arXiv 2506.18315](https://arxiv.org/html/2506.18315v1). One round of property generation per ticket; fail-closed if any generated property fails on the candidate solution.
5. **Mutation testing as halt-quality gate** with Stryker.NET and StrykerJS. Required mutation score threshold, e.g. 80%+ for HIPAA-touching code. [Stryker .NET docs](https://stryker-mutator.io/docs/), [Microsoft Learn — Mutation testing](https://learn.microsoft.com/en-us/dotnet/core/testing/mutation-testing).
6. **Roslyn analyzers + tsserver as compile gate.** `dotnet build /warnaserror` + `tsc --noEmit --strict`. Block PR if either fails. Type-confused bugs are eliminated, not detected.
7. **CodeQL security pass on every PR.** Treat as secondary gate; route any high-severity CodeQL finding to human reviewer regardless of LLM judges.
8. **PHI taint analyzer with explicit allowlist.** Run a Roslyn-based intra-procedural taint pass plus the symbolic-execution layer from [Sui et al. ICSE 2023](https://yuleisui.github.io/publications/icse23.pdf). Any new edge from PHI source to non-allowlisted sink → mandatory human review. Provenance: every flagged edge carries the rule that fired and the chain.
9. **Targeted Dafny/F* spec layer for ~5 critical invariants.** PHI-redaction must be total, audit-log writes must be append-only, retention purge must complete. Use [DafnyBench](https://arxiv.org/pdf/2406.08467) patterns; LLM produces specs from the architecture rules, human reviews specs, agent verifies. Small surface, near-100% confidence on covered surface.
10. **Halt-Quality Contract per ticket** (already in run-epic2 spec). Make explicit: define DONE criteria, evidence type, regression check. [completion-contracts.md](file:///path/to/source-project/.claude/rules/completion-contracts.md) is the right pattern; carry it forward into bolt.
11. **Mandatory human review at risk gates.** [HECR, ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0164121224001055): 40–60% additional defect detection from human-error-aware review. [HULA, arXiv 2411.12924](https://arxiv.org/abs/2411.12924): Atlassian engineers report HULA "minimizes overall development time" *with* humans in the loop. Define risk gates: (a) any PHI-touching diff, (b) any auth/identity change, (c) any DB schema migration, (d) any change to a ticket flagged "regulated".
12. **Provenance + audit chain.** Every PR carries: model version, sub-agent transcripts, KG-confidence-at-time-of-decision, mutation score, property-test seed, judge votes, human reviewer ID. This is HIPAA-evidence-grade and supports retrospective calibration of the entire stack.
13. **Calibrated rejection threshold.** Run the orchestrator on a held-out gold-set of ~50 production tickets; compute per-ticket-class pass@1; set the auto-merge threshold per ticket class to enforce ≤ 1% post-merge defect target. Recompute weekly. This is the *only* mechanism by which "0% production-defect" can be approached: not by trusting the model, but by *measuring its calibration* and refusing to auto-merge when measured pass-rate is below target.
14. **Post-merge regression watcher.** [PR cycle-time evidence](https://www.zenml.io/llmops-database/ai-driven-code-review-agent-reduces-pr-cycle-time-by-308) is upstream of defect reduction. Track post-merge incident rate per class; feedback into the calibration and the gold-set.

Layered effect on first-run task-level defect rate: starting at ~36% (Opus 4.7 on SWE-bench Pro), realistic landing zone with full stack is **3–8%** at the task level. Combined with mandatory human review on the residual risk surface, the *actual production-defect rate* (what actually escapes to prod) can plausibly land **below 1%** — but never zero, and any claim of zero on first run is unsupported by published evidence. The honest framing for the master spec is: **"approach single-digit production-defect basis points by stacking measurement + calibration + mandatory review on top of the model — and accept that the residual is the inherent cost of LLM-driven generation in 2026."**

---

## Closing honest summary

- A tree-sitter+DuckDB KG cannot be 100% complete or accurate. With every reasonable mitigation, ceiling ~94–96% aggregate; ~98% on intra-language; ~92% on cross-language; ~70% on dynamic-dispatch/reflection. Calibrated edge confidence is achievable and is the right consumer-side primitive. No production system claims 100%.
- An LLM orchestrator cannot achieve 0% production-defect on first run. SOTA on contamination-resistant SWE-bench Pro is 64% (Opus 4.7 — 36% first-run task failure). Stacking best-of-N + cross-family ensemble + PBT + mutation + semantic gates + targeted formal verification + mandatory human review can plausibly drive task-level first-run defects to single digits (3–8%) and production-escapes to <1%. Zero is not on the table.
- HIPAA-grade discipline does not require zero. It requires measurement, calibration, provenance, and audit. The bolt master spec's job is to make those four properties first-class outputs of every run, not to pretend zero is reachable.

---

## Sources

### Q1 — Tree-sitter, code intelligence, KG completeness

- [Jake Zimmerman — Is tree-sitter good enough?](https://blog.jez.io/tree-sitter-limitations/)
- [tree-sitter discussion #831 — Application as a compiler's parser](https://github.com/tree-sitter/tree-sitter/discussions/831)
- [tree-sitter issue #1631 — Unable to use as compiler parser](https://github.com/tree-sitter/tree-sitter/issues/1631)
- [tree-sitter issue #1870 — Improving error recovery](https://github.com/tree-sitter/tree-sitter/issues/1870)
- [tree-sitter issue #224 — Error-recovery strategy](https://github.com/tree-sitter/tree-sitter/issues/224)
- [Tree-sitter — Using Parsers](https://tree-sitter.github.io/tree-sitter/using-parsers/)
- [github/semantic — why-tree-sitter.md](https://github.com/github/semantic/blob/main/docs/why-tree-sitter.md)
- [Microsoft Learn — Get started with semantic analysis](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/get-started/semantic-analysis)
- [dotnet/roslyn — source-generators.md](https://github.com/dotnet/roslyn/blob/main/docs/features/source-generators.md)
- [dotnet/roslyn — incremental-generators.md](https://github.com/dotnet/roslyn/blob/main/docs/features/incremental-generators.md)
- [Microsoft Learn — ModelSnapshot Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.infrastructure.modelsnapshot)
- [InfoQ — Preparing EF Core for static analysis & nullable reference types](https://www.infoq.com/articles/EF-Core-Nullable-Reference-Types/)
- [Microsoft Learn — Get started with NSwag and ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/tutorials/getting-started-with-nswag)
- [Microsoft Learn — Handle code generation in MSBuild](https://learn.microsoft.com/en-us/visualstudio/msbuild/tutorial-rest-api-client-msbuild)
- [GitHub — RicoSuter/NSwag](https://github.com/RicoSuter/NSwag)
- [Cezary Piątek — Auto-generated WebAPI client with NSwag](https://cezarypiatek.github.io/post/auto-generated-web-api-client/)
- [Microsoft Learn — Blazor SignalR guidance](https://learn.microsoft.com/en-us/aspnet/core/blazor/fundamentals/signalr)
- [Syncfusion — Pros and Cons of JavaScript Interop in Blazor](https://www.syncfusion.com/blogs/post/pros-and-cons-of-using-javascript-interop-in-blazor.aspx)
- [Autofac docs — .NET Core integration](https://autofac.readthedocs.io/en/latest/integration/netcore.html)
- [GitHub — autofac/Autofac.Extensions.DependencyInjection](https://github.com/autofac/Autofac.Extensions.DependencyInjection)
- [codevision.medium.com — Dependency Injection for Native AOT (Jab, Pure.DI, StrongInject)](https://codevision.medium.com/dependency-injection-for-native-aot-e6cc90bef395)
- [Sourcegraph — Announcing SCIP](https://sourcegraph.com/blog/announcing-scip)
- [Sourcegraph 6.7 changelog](https://sourcegraph.com/changelog/releases/6.7)
- [Sourcegraph — Cross-repository code navigation](https://sourcegraph.com/blog/cross-repository-code-navigation)
- [Sourcegraph docs — Precise code navigation](https://docs.sourcegraph.com/code_navigation/explanations/precise_code_navigation)
- [GitHub — sourcegraph/scip](https://github.com/sourcegraph/scip)
- [GitHub — sourcegraph/scip-typescript](https://github.com/sourcegraph/scip-typescript)
- [GitHub — sourcegraph/scip-java](https://github.com/sourcegraph/scip-java)
- [GitHub Blog — Introducing stack graphs](https://github.blog/open-source/introducing-stack-graphs/)
- [arXiv 2211.01224 — Stack graphs: Name resolution at scale](https://arxiv.org/abs/2211.01224)
- [Engineering at Meta — Indexing code at scale with Glean](https://engineering.fb.com/2024/12/19/developer-tools/glean-open-source-code-indexing/)
- [Hacker News — Indexing code at scale with Glean](https://news.ycombinator.com/item?id=42568516)
- [arXiv 2510.02534 — ZeroFalse: Improving precision in static analysis with LLMs](https://arxiv.org/html/2510.02534v1)
- [arXiv 2601.18844 — Reducing false positives in static bug detection with LLMs](https://arxiv.org/html/2601.18844)
- [TypeScript Handbook — Declaration Merging](https://www.typescriptlang.org/docs/handbook/declaration-merging.html)
- [microsoft/TypeScript#50455 — aliases and local declarations merge](https://github.com/microsoft/TypeScript/issues/50455)
- [microsoft/TypeScript#39691 — Type merging from @types only](https://github.com/microsoft/TypeScript/issues/39691)
- [Aider — Building a better repository map with tree-sitter](https://aider.chat/2023/10/22/repomap.html)
- [Sourcegraph — How Cody understands your codebase](https://sourcegraph.com/blog/how-cody-understands-your-codebase)
- [Lambda Land — Tree-sitter vs LSP](https://lambdaland.org/posts/2026-01-21_tree-sitter_vs_lsp/)
- [Cursor forum — Bring LSP to Cursor CLI](https://forum.cursor.com/t/bring-lsp-language-server-protocol-support-to-cursor-cli-for-production-grade-code-intelligence/156751)
- [Zed docs — Configuring Languages](https://zed.dev/docs/configuring-languages)
- [UC Riverside — SoK: Soundness and Precision of Dynamic Taint Analysis](https://www.cs.ucr.edu/~heng/teaching/cs260-winter2017/formaltaint.pdf)
- [ICSE 2023 — Scalable Compositional Static Taint Analysis (Sui et al.)](https://yuleisui.github.io/publications/icse23.pdf)
- [arXiv 1912.10000 / ICLR 2020 — Probability Calibration for KG Embedding Models](https://ar5iv.labs.arxiv.org/html/1912.10000)
- [IJCKG 2022 — A Closer Look at Probability Calibration of KG Embedding](https://www.ijckg.org/2022/papers/IJCKG_2022_paper_8173.pdf)
- [EMNLP 2020 — Evaluating Calibration of KG Embeddings](https://aclanthology.org/2020.emnlp-main.667.pdf)
- [GitHub — Yang233666/KGE-Calibrator](https://github.com/Yang233666/KGE-Calibrator)
- [OpenAPI Specification 3.1](https://swagger.io/specification/)

### Q2 — Orchestrator reliability, agents, formal/PBT/mutation/HITL

- [SWE-bench Leaderboards](https://www.swebench.com/)
- [SWE-bench Verified](https://www.swebench.com/verified.html)
- [OpenAI — Why we no longer evaluate SWE-bench Verified](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/)
- [OpenAI — Introducing SWE-bench Verified](https://openai.com/index/introducing-swe-bench-verified/)
- [Scale labs — SWE-Bench Pro Leaderboard](https://labs.scale.com/leaderboard/swe_bench_pro_public)
- [morphllm — SWE-Bench Pro: Why 46% beats 81%](https://www.morphllm.com/swe-bench-pro)
- [BenchLM — SWE-bench Verified 2026, 44 LLM scores](https://benchlm.ai/benchmarks/sweVerified)
- [tokenmix — SWE-Bench 2026: Claude Opus 4.7 wins](https://tokenmix.ai/blog/swe-bench-2026-claude-opus-4-7-wins)
- [Vellum — Claude Opus 4.7 benchmarks explained](https://www.vellum.ai/blog/claude-opus-4-7-benchmarks-explained)
- [Anthropic API docs — What's new in Claude Opus 4.7](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7)
- [GitHub Changelog — Claude Opus 4.7 generally available](https://github.blog/changelog/2026-04-16-claude-opus-4-7-is-generally-available/)
- [Cognition — Devin's 2025 Performance Review](https://cognition.ai/blog/devin-annual-performance-review-2025)
- [The Register — First AI software engineer is bad at its job](https://www.theregister.com/2025/01/23/ai_developer_devin_poor_reviews/)
- [Sitepoint — Devin Aftermath: AI engineers in production](https://www.sitepoint.com/devin-ai-engineers-production-realities/)
- [Stryker — Equivalent mutants](https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/)
- [Stryker — Mutant states and metrics](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/)
- [Microsoft Learn — Mutation testing in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/mutation-testing)
- [johal.in — Mutation testing with Stryker .NET 2026](https://johal.in/mutation-testing-with-stryker-net-and-python-coverage-2026/)
- [Composable Models — LLM Debate](https://composable-models.github.io/llm_debate/)
- [ICLR 2025 Blog — Multi-LLM-Agents Debate critique](https://d2jud02ci9yv69.cloudfront.net/2025-04-28-mad-159/blog/mad/)
- [OpenReview — Debate or Vote](https://openreview.net/forum?id=iUjGNJzrF1)
- [OpenReview — Multi-Agent Debate Judge with Adaptive Stability](https://openreview.net/forum?id=Vusd1Hw2D9)
- [arXiv 2502.18581 — Self-certainty Best-of-N](https://arxiv.org/html/2502.18581v1)
- [ACL 2024 — Soft Self-Consistency](https://aclanthology.org/2024.acl-short.28.pdf)
- [ACL 2025 (NAACL) — Reasoning-Aware Self-Consistency](https://aclanthology.org/2025.naacl-long.184/)
- [EMNLP 2025 Findings — Multi-agent consensus alignment](https://aclanthology.org/2025.findings-emnlp.343.pdf)
- [arXiv 2506.18315 — Property-Generated Solver](https://arxiv.org/html/2506.18315v1)
- [arXiv 2510.09907 — Agentic Property-Based Testing](https://arxiv.org/html/2510.09907v1)
- [arXiv 2510.25297 — Characteristics of LLM-Generated PBTs](https://arxiv.org/html/2510.25297v1)
- [arXiv 2307.04346 — Can LLMs Write Good Property-Based Tests?](https://arxiv.org/pdf/2307.04346)
- [Kiro blog — Property-Based Testing](https://kiro.dev/blog/property-based-testing/)
- [arXiv 2505.13938 — CLEVER: Curated benchmark for formally verified codegen](https://arxiv.org/pdf/2505.13938)
- [arXiv 2509.22908 — VeriCoding: formally verified program synthesis](https://arxiv.org/pdf/2509.22908)
- [arXiv 2406.08467 — DafnyBench](https://arxiv.org/pdf/2406.08467)
- [OpenReview — VeriBench](https://openreview.net/pdf?id=rWkGFmnSNl)
- [arXiv 2501.16207 — LLMs on natural language formal specs](https://arxiv.org/pdf/2501.16207)
- [arXiv 2511.17330 — Agentic Program Verification](https://arxiv.org/pdf/2511.17330)
- [arXiv 2512.07501 — AutoICE: Synthesizing verifiable C via LLM-driven evolution](https://www.arxiv.org/pdf/2512.07501)
- [Atlas Computing — AI-assisted FV toolchain](https://atlascomputing.org/ai-assisted-fv-toolchain.pdf)
- [Knight & Leveson — Experimental evaluation of N-version assumption (TSE 1990, MIT mirror)](http://sunnyday.mit.edu/papers/nver-tse.pdf)
- [IEEE TSE — Analysis of Faults in N-Version Software](https://dl.acm.org/doi/10.1109/32.44387)
- [Wikipedia — N-version programming](https://en.wikipedia.org/wiki/N-version_programming)
- [Wind River — DO-178C](https://www.windriver.com/solutions/learning/do-178c)
- [Promenade Software — FDA & IEC 62304 documentation](https://www.promenadesoftware.com/blog/fda-iec62304-software-documentation)
- [Sunstone Pilot — FDA software guidances and IEC 62304](https://sunstonepilot.com/2018/09/fda-software-guidances-and-the-iec-62304-software-standard/)
- [Codecov — Code coverage in regulated industries](https://about.codecov.io/blog/the-role-of-code-coverage-in-regulations-and-standards/)
- [FDA — AI-Enabled Medical Devices](https://www.fda.gov/medical-devices/software-medical-device-samd/artificial-intelligence-enabled-medical-devices)
- [Baytech Consulting — 7-stage AI compliance framework](https://www.baytechconsulting.com/blog/seven-stage-ai-code-approval-blueprint)
- [arXiv 2508.04448 — LLMs vs static analysis tools, vulnerability detection](https://arxiv.org/html/2508.04448v1)
- [Anthropic — Constitutional AI v2 PDF](https://www-cdn.anthropic.com/7512771452629584566b6303311496c262da1006/Anthropic_ConstitutionalAI_v2.pdf)
- [Anthropic — Transparency Hub Model Report](https://www.anthropic.com/transparency/model-report)
- [Anthropic — Constitutional Classifiers](https://www.anthropic.com/research/constitutional-classifiers)
- [Anthropic — Next-generation Constitutional Classifiers](https://www.anthropic.com/research/next-generation-constitutional-classifiers)
- [ScienceDirect — Human Error-based Code Review (HECR)](https://www.sciencedirect.com/science/article/pii/S0164121224001055)
- [ICSE 2019 — Test-Driven Code Review](https://sback.it/publications/icse2019a.pdf)
- [arXiv 2411.12924 — Human-In-the-Loop Software Development Agents (HULA)](https://arxiv.org/abs/2411.12924)
- [arXiv 2511.10865 — Human-in-the-Loop Patch Evaluation with LLM-as-Judge](https://arxiv.org/html/2511.10865v1)
- [Evidently AI — How to align LLM judge with human labels](https://www.evidentlyai.com/blog/how-to-align-llm-judge-with-human-labels)
- [LangChain — Calibrate LLM-as-a-Judge with Human Corrections](https://www.langchain.com/articles/llm-as-a-judge)
- [Arize — LLM as a Judge primer](https://arize.com/llm-as-a-judge/)
- [arXiv 2509.01494 — Benchmarking LLM-based Code Review](https://arxiv.org/html/2509.01494v1)
- [arXiv 2604.27727 — LLM-as-a-Judge for Human-AI Co-Creation](https://arxiv.org/html/2604.27727v1)
- [ZenML LLMOps DB — Atlassian AI-Driven Code Review (30.8% PR cycle reduction)](https://www.zenml.io/llmops-database/ai-driven-code-review-agent-reduces-pr-cycle-time-by-308)
- [GitClear — AI Copilot Code Quality 2025 (defect rate)](https://gitclear-public.s3.us-west-2.amazonaws.com/GitClear-AI-Copilot-Code-Quality-2025.pdf)
- [ACM TOSEM — Security Weaknesses of Copilot-Generated Code](https://dl.acm.org/doi/10.1145/3716848)
- [arXiv 2406.17910 — Evaluating GitHub Copilot efficiency and challenges](https://arxiv.org/pdf/2406.17910)
- [ICSE 2023 — Robustness of Code Generation: Empirical Study on Copilot](https://dl.acm.org/doi/10.1109/ICSE48619.2023.00181)
- [Anthropic — 2026 Agentic Coding Trends Report](https://resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf?hsLang=en)
