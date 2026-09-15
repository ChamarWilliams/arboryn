# Arboryn

Arboryn is a local-first three-way merge engine for Roblox object trees. The repository is currently in **Phase 0: capture fidelity**. No merge engine exists yet.

The authoritative architecture and phase boundaries are recorded in [the locked design document](docs/rbx-merge-design-final.md).

Phase 0 answers one question before the product proceeds:

> Can a Studio plugin observe and round-trip enough of a real DataModel to support trustworthy semantic merging?

## Start here

1. Install [Rokit](https://github.com/rojo-rbx/rokit) on Windows or macOS.
2. Run `rokit install` from this repository.
3. Run the platform check script:

   ```powershell
   .\scripts\check.ps1
   ```

   ```bash
   ./scripts/check.sh
   ```

4. Build the Studio plugin with `rojo build plugin.project.json --output build/ArborynPhase0.rbxm`.
5. Follow [the Phase 0 runbook](docs/phase-0/runbook.md).

With Studio closed, run `scripts/smoke-studio.ps1` or `scripts/smoke-studio.sh` for a real plugin-security API smoke test in a disposable place.

## Current scope

- Luau Studio capture and measurement harness
- Reflection-derived property inventory
- Explicit capture gaps instead of silent omission
- Native `.rbxm` serialization round-trip probe
- Repeatable fixture and report formats

Rust crates, merge behavior, identity assignment, cloud services, MCP, deployments, and product UI are intentionally not part of Phase 0.

## Status

The harness builds and passes static checks. Real Studio capture results have not been collected yet, so Phase 0 has not passed.
