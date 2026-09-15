# Phase 0 fixture matrix

| Area | Controlled fixture | Real-place evidence required |
|---|---|---|
| Hierarchy | Model, folder, duplicate class/name handling | Rename, move, reparent, mass paste |
| Properties | Primitives, transforms, enums, sequences | High-risk class/property inventory |
| Source | Disabled Script populated through ScriptEditorService | Real script edits and overlapping saves |
| Metadata | Attributes and CollectionService tags | Add/remove and undo/redo |
| References | Beam attachments and external ObjectValue | Delete target and cross-boundary reference |
| UI | SurfaceGui and TextLabel | Representative production UI tree |
| Observation | Not yet implemented | Isolated, batched, undo/redo, remote Team Create |
| Scale | Small deterministic model | 20k+ instance place |

The controlled fixture proves harness behavior only. It cannot establish production coverage.
