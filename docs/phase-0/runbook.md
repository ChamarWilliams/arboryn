# Phase 0 runbook

Phase 0 measures Studio capture fidelity. It does not implement identity, diff, merge, apply, Git semantics, a service, or a production UI.

## 1. Prepare the toolchain

Run `rokit install`, then `scripts/check.ps1` on Windows or `scripts/check.sh` on macOS. Install the matching Rojo Studio plugin with `rojo plugin install`.

## 2. Build and install the harness

```powershell
rojo build plugin.project.json --output build/ArborynPhase0.rbxm
```

Move `build/ArborynPhase0.rbxm` into the Studio plugins folder, or open that folder through Studio's **Plugins Folder** command. Restart Studio after replacing the file.

## 3. Run the controlled probe

1. Open a disposable local place—not a production place.
2. Open **Plugins → Arboryn → Phase 0 Probe**.
3. Select **Build controlled fixture**. The known fixture is created in `ServerStorage` through a Studio undo recording.
4. Select **Run selected-root round trip**.
5. Preserve the JSON emitted in Studio Output. The plugin also stores the latest report in its local plugin settings under `ArborynPhase0LatestReport`.
6. Record Studio version, operating system, fixture version, duration, serialized size, readable-property count, capture gaps, unsupported values, and semantic equality.

The controlled fixture includes parts/models/folders/scripts, attributes, tags, internal and external references, attachments, a beam, UI, transforms, and sequences.

## 4. Expand to representative places

Repeat against copies of real places at small, medium, and 20k+ instance sizes. Never begin with the production copy. Capture isolated and batched edits for rename, move, reparent, duplicate, delete, paste, undo, redo, script edits, tags, attributes, references, package insertion, and Team Create remote edits.

For each place, independently save `.rbxlx` and retain it outside Git under `artifacts/phase-0/`. Comparing the plugin capture with `rbx_xml` is a later analysis step in Phase 0; this Luau-only starting scaffold deliberately does not introduce Rust implementation code.

## 5. Classify every gap

Every unreadable or unsupported property must be assigned exactly one category:

- `safe_omission`
- `opaque_preservable`
- `merge_blocking`
- `round_trip_breaking`

Do not convert an unreadable property into a successful result, and do not infer object identity from structural similarity.

## 6. Decide

The final Phase 0 decision must be one of:

- `PROCEED`
- `PROCEED_WITH_EXCLUSIONS`
- `STOP`

No merge-engine implementation begins while the decision is `UNASSESSED`.
