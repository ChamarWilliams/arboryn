# rbx-merge

## Design document

**Status:** Architecture draft locked for deliberation; pre-implementation
**Scope:** One problem, solved completely
**Audience:** Me, and anyone who picks this up later

---

## 1. What this is

A three-way merge engine for Roblox object trees, with a Studio plugin that feeds it.

That is the entire product. Everything else that might eventually attach to it — cloud, deployments, analytics, agent interfaces — is out of scope and stays out of scope until the merge engine is proven correct on real place files.

## 2. Why it exists

I lose work to Team Create. Two people touch the same hierarchy, one overwrites the other, and there is no record of what happened or any way to recover a specific object's prior state. Rojo solves the file half well and the object half partially, because reverse sync has no persistent identity to anchor against and no notion of a common ancestor. Git treats a `.rbxl` as an opaque blob.

The missing primitive is not sync. It is a durable identity for each instance plus a merge that can reason about a base revision. Nothing in the ecosystem provides it.

This is built for me first. If other people want it, that is a later conversation and a later document.

## 3. The one hard problem

Everything in this design depends on a question I have not answered yet:

> Can a Studio plugin observe enough of the DataModel, accurately enough and fast enough, to reconstruct a faithful object tree?

If the answer is no, there is no product. The Luau plugin API has no global property-change feed. Some properties are not scriptable. Some are not readable at all. A merge engine that silently drops properties it could not see is worse than no merge engine, because it produces confident, wrong results.

Phase 0 answers this question before anything else is built. The measured property-coverage number from Phase 0 is the single most important fact in this project, and it becomes a permanent constraint documented in the repository.

## 4. Decisions

These are decided, not open. Each records why and what it would cost to reverse.

**D1. Object identity is a hybrid: sidecar canonical, attribute advisory.**
A sidecar file in the repository is the authoritative ID map. A namespaced attribute on the instance is a recovery hint for when the sidecar and the tree disagree. Attributes alone are too easy to lose (copy/paste, asset import, plugin interference). Sidecars alone cannot survive a Studio-side reparent that the service did not observe. Reversal cost: moderate, contained to the `identity` module.

**D2. The accepted revision is the source of truth. Studio and the filesystem are working views.**
Neither side "wins." Both propose changes against a known base. This is what makes three-way merge possible at all, and it is the reason this is not a Rojo fork — Rojo's model has no accepted revision to anchor against. Reversal cost: total. This is the architecture.

**D3. Continuous observation, explicit application.**
The service watches and computes constantly. It writes only when asked, and never without a preview when the change is destructive, conflicting, or crosses an ownership boundary. Auto-apply for trivially safe changes is a later opt-in, not a default. Reversal cost: low.

**D4. Build on rbx-dom. Do not write an object model.**
`rbx_dom_weak`, `rbx_binary`, `rbx_xml` are maintained, correct, and the ecosystem standard. Writing my own costs months and buys nothing. Reversal cost: high and pointless.

**D5. Rust for the engine, Luau for the Studio integration.**
The product ships with two implementation languages at first: Rust owns correctness-critical behavior; Luau owns Studio integration. TypeScript may enter later for a user-facing web/desktop review surface, and Python may exist under tooling for analysis, fixture generation, and research, but neither is part of the merge path. No merge, identity, revision, or apply semantics are duplicated outside Rust. Reversal cost: none, additive.

**D6. Local-first. No required network dependency.**
The service binds to localhost and the core product works with Studio, the filesystem, and Git while fully offline. No account, hosted control plane, telemetry, or cloud dependency is required for correctness. Cloud synchronization, if added later, distributes revisions and collaboration metadata; it does not become the authority for an active Studio session. Reversal cost: low now, high later.

**D7. Studio is the primary human interface; the CLI is equally authoritative.**
Normal interactive use happens through a Studio plugin UI. Power users also get a plugin command palette and a Luau command API where practical. CI, Git automation, debugging, and headless use go through the Rust CLI. All surfaces call the same Rust operations; no surface implements its own merge behavior. Reversal cost: low.

**D8. Git provides ancestry and transport; rbxm provides object semantics.**
Git commits and branches are not the merge model. An immutable rbxm revision may be associated with a Git commit, branches remain movable Git refs, and semantic merges are performed by rbxm using the common base revision. Git never decides instance identity or Roblox object conflicts. Reversal cost: high once repositories depend on the mapping.

**D9. Observation events are advisory; snapshots are authoritative.**
Studio signals, `ChangeHistoryService`, and dirty-region tracking exist to reduce latency and avoid unnecessary full walks. They do not establish truth by themselves. Before any correctness-sensitive decision, rbxm compares captured state against its known snapshot model. Periodic reconciliation detects events that Studio failed to surface. Reversal cost: moderate; this shapes the capture architecture.

**D10. The on-disk representation is normalized, deterministic, and identity-independent from paths.**
Scripts are stored as plain `.luau` source. Mergeable instance metadata is serialized in deterministic human-readable form, initially JSON. Instance references serialize by `stable_id`, never hierarchy path. Unsupported or opaque values use explicit typed encodings rather than lossy conversion. Paths exist for human organization only; moving or renaming an object does not change its identity. Reversal cost: high after repositories depend on the format.

**D11. Identity sidecars are per-container and threshold-sharded.**
One global identity file creates unnecessary Git contention; one file per instance creates pathological file counts. Identity metadata begins grouped by logical container/subtree and is split deterministically when a size/count threshold is exceeded. Exact thresholds are measured, not guessed. Reversal cost: moderate.

**D12. Child order significance is explicit, versioned, and conservative.**
A hardcoded versioned allowlist determines which classes/containers require meaningful child order. All others are treated as unordered. Heuristics are not used in the initial product because silently guessing order significance is unsafe. Reversal cost: low.

**D13. Accepted revisions form an immutable DAG.**
Ordinary accepted revisions have one parent; semantic merge revisions have two. Observation alone does not create a revision. A revision is created only by an approved atomic transaction, completed merge/conflict resolution, or explicit checkpoint. Revision identity is derived from canonical revision metadata, including parent revision IDs, resulting state hash, schema version, and originating change-set identity; identical object states reached through different histories may therefore have different revision IDs while sharing a state hash. Reversal cost: high.

**D14. Ownership boundaries are explicit and typed.**
Managed, external, generated, package-owned, and protected regions have distinct write policies. Unknown ownership is treated conservatively: destructive or cross-boundary writes require preview and cannot auto-apply. Rojo-managed and package-owned regions can be represented without making Rojo or packages the source of truth. Reversal cost: moderate.

**D15. Applies use a durable transaction journal.**
Before mutation, rbxm persists the base revision, forward change set, inverse change set, affected scope, and transaction phase. The minimum durable phases are `Prepared`, `Applying`, `Verified`, and `Accepted`, with interruption entering `FailedRecoverable`. An uncertain transaction never advances accepted HEAD. Reversal cost: high once data exists.

## 5. Architecture

```text
                        Roblox Studio
              +------------------------------+
              | Luau plugin                  |
              | - capture / observation      |
              | - visual review UI           |
              | - command palette            |
              | - Luau command API           |
              | - approved patch application |
              +---------------+--------------+
                              | localhost HTTP
                              v
                    +--------------------+
                    | Local service      |
                    | Rust               |
                    |                    |
                    | capture normalizer |
                    | identity resolver  |
                    | revision store     |
                    | diff / merge       |
                    | Git adapter        |
                    +----+-----------+---+
                         ^           |
                         |           v
                    +----+----+   +--------+
                    |   CLI   |   |  Git   |
                    +---------+   | repo   |
                                  +--------+
```

Four crates. Not eleven.

| Crate | Responsibility |
|---|---|
| `rbxm-core` | Instance records, change sets, revisions, serialization. Built on rbx-dom. |
| `rbxm-identity` | ID assignment, sidecar persistence, recovery, repair. |
| `rbxm-merge` | Diff, three-way merge, conflict classification. |
| `rbxm-cli` | Binary. CLI commands and the localhost service the plugin talks to. |

The plugin does one thing well: expose Studio to the engine. It reads and observes the DataModel, renders previews and conflicts, provides fast command access, selects or opens affected Studio objects, and applies approved patches through Studio APIs. Every correctness-critical or expensive operation lives in Rust. The plugin holds no authoritative state that is not recoverable from the service.

### Interaction surfaces

The same operation must behave identically regardless of how it was requested.

```text
Studio UI          [Merge origin/main]
Studio palette     rbxm> merge origin/main
Studio Luau API    rbxm.merge("origin/main")
System CLI         rbxm merge origin/main
                         |
                         v
                  same Rust operation
```

The plugin UI is the default human workflow because object moves, identity repairs, property conflicts, and script conflicts are easier to trust when the affected Studio objects can be inspected directly. The CLI remains first-class because CI and Git automation must work with Studio closed.

## 6. Data model

### Instance record

```text
InstanceRecord
├── stable_id        u128, assigned once, never reused
├── parent_id        Option<u128>
├── name             String
├── class_name       String
├── properties       Map<String, Variant>     (rbx-dom Variant)
├── attributes       Map<String, Variant>
├── tags             Set<String>
├── children_order   Option<Vec<u128>>        (None = order insignificant)
└── capture_gaps     Vec<String>              (properties known-unreadable)
```

`capture_gaps` is the honest part. Every property the plugin could not read is recorded by name. The merge engine refuses to merge an instance whose gaps overlap the properties under conflict, and says so, rather than guessing.

### Change set

```text
ChangeSet
├── id
├── base_revision
├── author
├── source            Studio | Filesystem | CLI
├── created_at
├── operations        Vec<Operation>
└── resulting_revision
```

### Operations

`CreateInstance`, `DeleteInstance`, `MoveInstance`, `RenameInstance`, `SetProperty`, `SetAttribute`, `RemoveAttribute`, `AddTag`, `RemoveTag`, `UpdateSource`, `ReorderChildren`.

Every operation carries `expected_prior` and `proposed_next`. An operation whose `expected_prior` does not match current state is stale and is rejected, not applied. This is the mechanism that makes concurrent edits safe, and it is non-negotiable.

### Revision

A revision is an immutable accepted object-tree state in a DAG. The implementation may use structural sharing internally, but the logical model is immutable.

```text
Revision
├── id
├── parent_revisions    Vec<RevisionId>       (normally 1; semantic merge = 2)
├── state_hash          Hash                  canonical semantic state
├── state               canonical object-tree snapshot/reference
├── schema_version
├── created_from        Option<ChangeSetId>
└── created_at
```

A given base revision plus a given valid change set must always produce the same resulting semantic state. Revision IDs are derived from canonical revision metadata rather than Git branch names or the state hash alone. Two revisions may therefore have the same `state_hash` while remaining distinct because their ancestry differs. Branches move; revisions do not.

Observation does not create accepted history by itself. Dirty working state may accumulate indefinitely. A new accepted revision is created only when an approved atomic change set is accepted, a merge/conflict resolution completes, or the user explicitly checkpoints the current state.

### Identity resolution outcomes

Identity recovery is fallible and typed. Structural similarity is never enough to silently declare two objects identical.

```text
IdentityResolution
├── Resolved(stable_id)
├── NewObject(assign stable_id)
├── Ambiguous(candidates)
└── Conflict(details)
```

A duplicate, copy/paste, sidecar disagreement, missing advisory attribute, or reused ID may therefore block application and require repair instead of being guessed through.

## 7. Merge semantics

Three inputs: common base revision, local state, incoming state.

**Auto-merge:**
- Disjoint properties on the same instance
- Edits to different scripts
- Independent children added under the same parent where `children_order` is `None`
- A move on one side combined with a non-conflicting property edit on the other
- Tag additions from both sides (set union)

**Conflict:**
- Same property, different values, both differing from base
- Delete on one side, modify on the other
- Same instance moved to different parents
- Overlapping line regions in the same script
- Both sides reorder the same order-significant container
- Either side touches a property listed in the other's `capture_gaps`

**Never automatic:**
- Semantic conflicts. If two scripts both compile but disagree about intent, that is a human problem. No LLM resolution, ever. The engine's value is that its output is trustworthy.

Script merging uses standard line-based three-way merge on `Source`. Luau-aware merging is a later refinement, not a launch requirement.

### Reference properties

The DataModel is not only a tree. Parent/child relationships form a rooted tree, while `Ref` properties form a second reference graph between instances. A reference targets `stable_id`, never a hierarchy path. Rename and reparent therefore do not break a valid reference. Deleting a referenced instance, changing the same reference differently on both sides, or introducing a reference to an object deleted by the other side is a referential-integrity conflict until an explicit policy proves otherwise. Phase 1 does not exit until this matrix is specified and tested.

## 8. Safety invariants

These are enforced in code, asserted in tests, and never relaxed for convenience.

1. Never delete an instance the service has no prior record of. Quarantine it and surface it.
2. Never apply a change set whose `base_revision` is not the current revision. Rebase or reject.
3. Never apply an operation whose `expected_prior` does not match observed state.
4. Every apply goes through `ChangeHistoryService` so Studio undo works.
5. Every apply is reversible. The inverse change set is computed and stored before the forward one is applied.
6. Detected divergence between Studio state and the last accepted revision blocks all applies until reconciled.
7. Sidecar and attribute disagreement is a repair prompt, never a silent choice.
8. A partial apply is never accepted as a revision. Apply either commits completely or enters a recoverable blocked state with enough information to resume or reverse safely.
9. Git text-merge results never override rbxm identity or semantic conflict detection.

Invariant 1 is the one that matters most. The failure mode this product exists to prevent is silent data loss, so the engine must prefer refusing to act over acting wrongly.

## 9. Phases

Each phase has an exit criterion. No phase starts before the previous one exits.

### Phase 0 — Capture fidelity

Luau only. Nothing else is written.

- Plugin walks a full DataModel and serializes every readable property on every instance
- Diff that output against the same place saved as `.rbxlx` and parsed by `rbx_xml`
- Generate/consume expected Roblox class/property metadata so omission is distinguishable from unreadability, then produce overall readability, high-risk-property coverage, reference-property coverage, script coverage, class coverage, mutation-detection coverage, value-match rate, and a complete list of unreadable/unsupported properties
- Classify gaps as safe omission, opaque-but-preservable, merge-blocking, or round-trip-breaking
- Time a full walk on a 20k+ instance place; time incremental capture after isolated and batched edits
- Implement the hybrid observation candidate: signals/`ChangeHistoryService` mark dirty regions, incremental snapshots recapture those regions, and periodic reconciliation snapshots detect missed events
- Test rename, move, reparent, duplicate, delete, mass paste, undo, redo, package/asset insertion, script edits, tags, attributes, references, and Team Create remote edits
- Compare capture -> mutate -> capture against independently serialized `.rbxlx` state, not only a single final-state snapshot

**Exit:** high-risk property coverage and mutation detection are strong enough that `capture_gaps` is a manageable, explicit constraint rather than a source of silent loss, and there is a viable incremental observation strategy.
**Kill:** coverage would cause silent property loss, or every observation strategy requires a multi-second full walk.

### Phase 1 — Merge engine, offline

Rust. No Studio, no network, no config.

- Identity scheme, sidecar format, typed recovery outcomes, repair path
- Per-container identity sharding with deterministic threshold-based splitting
- Versioned child-order significance allowlist
- Deterministic normalized on-disk format and typed variant encodings
- Immutable revision model and deterministic resulting-state rules
- Change-set schema and serialization
- All eleven operations
- Apply and reverse
- Three-way merge
- Explicit `rebase(change_set, onto_revision)` semantics
- Reference-graph merge semantics and referential-integrity conflicts
- Conflict classification
- CLI: `diff`, `merge`, `apply`, `revert`, operating on `.rbxl` files

**Exit:** the full conflict matrix passes, and apply-then-reverse is identity over randomized fixtures.
**Kill:** conflict classification is ambiguous often enough that output cannot be trusted, or identity cannot survive rename + move + reparent.

### Phase 2 — Studio bridge

- Localhost service, single process
- Plugin capture, transport, preview, apply
- Preview UI showing object, property, and script diffs before any write
- Plugin command palette for fast Studio-native commands
- Luau command API where Studio permits it
- Divergence detection and reconciliation flow
- Transactional apply/recovery protocol for plugin/service interruption
- All safety invariants enforced and tested

**Exit:** the demonstration in §15 runs against my own project.

### Phase 3 — Git

Git is ancestry, review, and transport. It does not become the Roblox merge engine.

- Map immutable rbxm revisions to Git commits; do not map revisions directly to mutable branches
- Track authoritative revision metadata in the repository; commit trailers may mirror it for humans but are not the sole source
- Materialize a Git-readable representation without allowing Git paths or rename heuristics to determine object identity
- Use Git merge-base to identify the common ancestor, then invoke the rbxm three-way merge
- Add `rbxm status`, `rbxm commit`, `rbxm merge`, semantic `rbxm rebase`, `rbxm conflicts`, and repository verification
- Define behavior for dirty working trees, branch switching while Studio is open, raw Git operations, rebases, squash merges, force-pushes, and revision/Git divergence
- Commit and PR summaries rendered as object-level changes rather than blob diffs
- CI checks for revision integrity, stable-ID collisions, semantic mergeability, and object-level diff summaries
- Git text merges of identity metadata are always revalidated by rbxm before acceptance

**Exit:** a pull request where the Studio-side changes are legible to a reviewer who never opens Studio, and a branch merge can be reproduced from Git ancestry plus rbxm revision metadata without relying on Git's line merge for object semantics.

## 10. On-disk representation

The repository representation exists for persistence, inspection, review, and Git transport. It is not the identity model and Git does not own semantic merge behavior.

**Scripts** are stored as plain `.luau` files wherever possible. **Mergeable instance metadata** is stored in deterministic normalized JSON initially. Keys, enum forms, numeric formatting, typed variants, and child ordering are canonicalized so rewriting unchanged state does not create noisy diffs. **References** use `stable_id`, never hierarchy paths. **Opaque or awkward Roblox values** use explicit typed encodings with enough information to round-trip safely rather than being coerced into lossy JSON primitives.

Paths are organizational only. A rename or reparent may change the path visible to humans, but identity remains the same because it is anchored by `stable_id`. Git rename detection is therefore never consulted for identity recovery.

Identity metadata is grouped by logical container/subtree and deterministically sharded after a measured size/count threshold. The exact threshold is an implementation benchmark, not an architecture question. Child ordering is serialized only for classes/containers on the versioned order-significance allowlist.

Example shape:

```text
game/
├── ServerScriptService/
│   └── Combat.server.luau
├── ReplicatedStorage/
│   └── Weapons/
│       └── Katana/
│           ├── instance.rbxm.json
│           └── Hitbox.rbxm.json
└── .rbxm/
    ├── revision.json
    ├── identity/
    └── config.toml
```

The exact file grouping may evolve during Phase 1, but any accepted format must satisfy: deterministic output, stable-ID references, semantic round-trip fidelity, low rename/reparent churn, bounded file counts, and readable Git review.

## 11. Git contract

The durable association is `Git commit SHA <-> immutable rbxm revision ID`. A branch is only a movable Git ref to a commit. Multiple fine-grained local rbxm revisions may be squashed into one Git commit when the user chooses to publish work.

Recommended repository metadata begins minimal:

```text
.rbxm/
├── revision.json
├── identity/
└── config.toml
```

`revision.json` records the accepted revision and a semantic state hash. The exact on-disk identity granularity remains open, but one monolithic identity file is discouraged because it creates unnecessary Git contention.

`rbxm merge <ref>` resolves the Git merge base, loads the associated base/local/incoming rbxm revisions, performs the semantic merge, and only then materializes the result for Git. Raw `git merge` remains possible but is not the recommended object-changing workflow; repository verification must detect when raw Git operations leave rbxm metadata inconsistent.

Semantic rebase means replaying or remerging rbxm change sets onto a new accepted base, not blindly applying serialized Git patches. Rebased revisions receive new ancestry and therefore new revision IDs even when their user-visible changes are equivalent.

### Raw Git compatibility policy

Read-only Git operations (`fetch`, `status`, `log`, `show`, `diff`, branch inspection) are unrestricted. State-changing Git operations (`checkout`/`switch`, `reset`, `merge`, `rebase`, and equivalents) are not prohibited, but rbxm treats the resulting repository state as potentially divergent. Before any subsequent Studio or filesystem apply, rbxm verifies the checked-out commit's revision metadata and semantic state. If they disagree, all applies are blocked until reconciliation.

`rbxm checkout`, `rbxm merge`, `rbxm rebase`, and `rbxm commit` are the recommended workflows because they can preserve semantic ancestry and verify state before publication. Force-push changes remote Git history, not the immutable local rbxm revision graph; synchronization must therefore reason about moved Git refs without rewriting accepted rbxm revisions.

## 12. Studio UX state machine

The plugin UI is not a generic terminal embedded in Studio. It is a stateful review surface over the same engine used by the CLI.

```text
Clean
  -> ObservedChanges
  -> Previewing
  -> Applying
  -> Clean

ObservedChanges / Previewing
  -> Conflict
  -> IdentityRepairRequired
  -> Diverged

Applying
  -> ApplyFailedRecoverable
```

Each state has an explicit allowed-action set. A conflict row should be able to select the affected instance in Explorer; a script conflict should be able to open the script; identity repair should show the competing candidates rather than silently choosing one.

The plugin exposes three Studio-facing interaction modes over one backend:

```text
Visual UI        normal workflow
Command palette  rbxm> status / diff / merge ...
Luau API         rbxm.status(), rbxm.diff(), rbxm.merge(...) where practical
```

The external Rust CLI is the fourth surface and exists for CI, Git automation, headless work, and debugging.

### Ownership boundaries

Every managed region has an ownership classification:

```text
Managed        rbxm may propose and apply approved semantic changes
External       observable, but writes require explicit boundary handling
Generated      regenerated by another tool; direct edits are normally blocked
PackageOwned   governed by package semantics; destructive edits require explicit review
Protected      no automatic writes; explicit user action required
```

Unknown ownership is treated as protected for destructive behavior. Crossing a boundary is always previewed. Auto-apply, if it ever exists, is limited to changes proven safe inside `Managed` regions.

## 13. Transaction and recovery model

Application is transactional at the rbxm level even though Studio, Git, and the filesystem do not share one database transaction. Before any forward mutation, the engine durably writes a journal record containing:

```text
TransactionRecord
├── transaction_id
├── base_revision
├── forward_changeset
├── inverse_changeset
├── affected_scope
├── expected_pre_state_hash
├── expected_post_state_hash
└── phase
```

The minimum state machine is:

```text
Prepared -> Applying -> Verified -> Accepted
                  \-> FailedRecoverable
```

`Prepared` means all rollback information is durable before the first mutation. `Applying` means at least one external write may have happened. `Verified` means the affected Studio/filesystem state has been recaptured and matches the intended post-state. Only `Accepted` advances the accepted revision. A crash, Studio close, plugin disconnect, partial filesystem write, or process termination may leave `FailedRecoverable`, but must never silently advance HEAD.

On reconnect, rbxm compares the observed state against the journal's expected pre/post states. If it exactly matches the pre-state, the apply can safely restart. If it exactly matches the expected post-state, verification can finish. If it matches neither, the project enters reconciliation and offers resume, reverse, or explicit repair based on what can be proven.

## 14. Deferred extension boundaries

Cloud, MCP, TypeScript UI, and Python tooling are allowed later only behind stable core contracts.

**Cloud:** optional synchronization/collaboration layer for revisions, metadata, review, backup, and remote coordination. The active local session remains usable offline. Cloud does not bypass local validation or directly mutate Studio.

**MCP:** an adapter over the Rust service, not a second engine. Read-only tools such as revision/tree/diff/conflict inspection may be exposed first. Mutating agent operations must produce normal change sets and pass the same preview, base-revision, identity, and `expected_prior` checks as human actions.

**TypeScript:** permitted for a future external review/history UI when Studio UI is no longer sufficient. It never owns merge semantics.

**Python:** permitted for experiments, benchmark analysis, fixture generation, migration scripts, and research under tooling. It is not part of the authoritative runtime path.

## 15. The demonstration

One scenario decides whether this works:

> Developer A changes a script through Git. Developer B, in Studio, changes a property, moves an object, and creates an instance. Both changes are captured as persistent change sets against a common base. Object identity survives the move. Independent edits merge automatically. A genuine conflict is surfaced with both sides visible. Neither developer's work is silently lost.

If this runs, the foundation is real. If it does not, nothing built on top of it would have mattered.

## 16. Testing

- Golden fixtures for object trees and change sets, committed to the repo
- Round-trip: place file → records → place file, byte-comparable where rbx-dom guarantees it, semantically comparable elsewhere
- Conflict matrix: every auto-merge case and every conflict case, named and fixtured
- Property tests: apply/reverse identity, merge commutativity where it should hold, merge determinism always
- Fuzzing on parsing and merge invariants
- Failure injection: partial writes, stale revisions, plugin disconnect mid-apply, concurrent CLI and plugin writes
- Every safety invariant from §8 has a dedicated test that asserts the engine refuses

CI on Windows, macOS, Linux. Windows first, since that is where Studio lives.

## 17. Non-goals

Permanent, not "later":

- Replacing Studio or Team Create
- LLM-based conflict resolution
- Real-time collaborative editing
- Being a Rojo replacement (it is an adapter target, not a competitor)

Deferred until the engine is proven and I personally need them:

- Hosted control plane, web console, accounts, cloud gateway, or required cloud dependency
- Database, storage, queue, and analytics connectors for a hosted product
- Dataset manifests, exports, notebooks, ML
- Environments, deployments, rollback, cost tracking
- MCP server, agent sessions, quotas, and agent worktrees until the local contracts are stable
- External TypeScript UI until Studio UI demonstrably becomes insufficient
- Automatic file organization and classification
- Org management, enterprise identity, audit retention
- Permission and policy engine

The permission engine is worth naming separately: it belongs to a product with multiple organizations, and this is a tool with one user. Adding it early would mean designing an authorization model against imaginary requirements.

## 18. Empirical validation questions

The architecture decisions above are closed for the first implementation. The remaining questions are measurements or lookup tables to determine during Phase 0/1, not reasons to reopen the model unless the evidence disproves an assumption.

1. **Capture coverage:** Which properties/classes are readable, unreadable, opaque-but-preservable, merge-blocking, or round-trip-breaking?
2. **Observation cost:** What signal strategy, dirty-region batching, and reconciliation interval provide acceptable latency on representative 20k+ instance places? Events remain advisory regardless of the answer.
3. **Mutation fidelity:** Which Studio operations can be detected incrementally, and which require reconciliation to recover missed state?
4. **Identity shard threshold:** At what object/file-size threshold should per-container identity metadata split to avoid both Git contention and pathological file counts?
5. **Order-significance table:** Which Roblox classes actually require stable child order, and how should that versioned allowlist change with Roblox API updates?
6. **Typed encoding coverage:** Which Roblox variants can be represented directly in normalized JSON and which require opaque typed encodings?
7. **Performance budgets:** What full-capture, incremental-capture, diff, merge, and apply latency is acceptable on real projects?
8. **Raw Git compatibility:** Validate the detection/reconciliation behavior after `checkout/switch`, `reset`, `merge`, `rebase`, squash merges, force-pushes, and dirty-tree transitions.

A failed measurement can force an architectural revision, but no unresolved design choice should be hidden behind these benchmarks.

## 19. Risks

**Platform risk.** Roblox ships first-party tooling on a regular cadence, and source control is an obvious gap in their offering. If they ship it, this becomes a personal tool, which is what it was built to be anyway. Accepted.

**Capture ceiling.** Phase 0 may return a coverage number that permits only partial merges. The mitigation is `capture_gaps` and explicit refusal, which degrades the product without making it dangerous.

**Rust learning curve on the hardest part of the codebase.** The merge engine is where the subtle bugs live, and it is also where I am least experienced. Mitigation: the conflict matrix is written as tests before the implementation, so correctness is measured rather than assumed. Generating code quickly does not help here — the tests are the design, and writing them is the slow part that cannot be skipped.

**Git representation risk.** A technically correct merge engine can still produce an unusable repository if ordinary object edits create excessive path churn or giant sidecar conflicts. Mitigation: treat on-disk representation as a measured Phase 1 design problem, not a serialization afterthought.

**Transactional boundary risk.** Studio, Git, and the filesystem do not share one atomic transaction mechanism. Mitigation: persist intent and inverse operations first, verify post-state before accepting a revision, and block on uncertain partial application.

**Scope creep.** The original version of this document described nine products. The mitigation is §17, and the discipline of keeping cloud, MCP, dashboard, and agent work behind stable local contracts.
