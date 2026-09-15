# Phase 0 report schema

Each raw report uses `schema_version: 1` and records:

- probe and capture timestamp
- Studio place/game identifiers
- selected root name and class
- instance, readable-property, capture-gap, and unsupported-value counts
- native serialized byte length
- serialization and deserialization durations
- normalized semantic equality
- original and deserialized instance records
- an explicit decision, initially `UNASSESSED`

Raw captures belong under ignored `artifacts/phase-0/`. Curated, reviewed summaries may be committed under `docs/phase-0/results/` after removing private project names and identifiers.
