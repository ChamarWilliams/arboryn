# Arboryn contributor instructions

## Active phase

Phase 0 is the only active implementation scope. Work may add Luau capture, fixtures, measurements, and documentation needed to decide capture fidelity.

Do not add Rust crates, identity assignment, diff or merge behavior, apply behavior, a localhost service, cloud features, MCP, analytics, accounts, deployments, or a production UI until Phase 0 has a reviewed `PROCEED` or `PROCEED_WITH_EXCLUSIONS` decision.

## Correctness rules

- Record every unreadable property as a capture gap; never silently omit it.
- Preserve unsupported values as explicit unsupported or opaque records; never coerce them into misleading primitives.
- Treat observation events as hints and snapshots as the evidence source.
- Do not infer persistent identity from names, paths, structure, or similarity.
- Run experiments only against controlled fixtures or disposable copies of places.
- Any fixture mutation must participate in Studio undo through `ChangeHistoryService`.
- Keep raw `.rbxl`, `.rbxlx`, `.rbxm`, and captured project data out of Git.

## Verification

Run `scripts/check.ps1` on Windows or `scripts/check.sh` on macOS before committing. A successful Rojo build is structural verification only; Phase 0 requires real Studio measurements.
