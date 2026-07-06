# BeamDrop Core

This directory contains the shared Rust foundation for BeamDrop. It is organized
as a Rust workspace so protocol, cryptography, transfer, discovery, persistence
models, and native binding boundaries can evolve independently.

## Crates

- `beamdrop-protocol`: protocol models, transfer types, platform enums,
  validation, and JSON serialization/deserialization.
- `beamdrop-crypto`: device key abstractions, peer fingerprints, SHA-256 helper,
  and a payload encryption interface.
- `beamdrop-transfer`: chunk calculation, transfer status, progress, resume
  planning, and final hash verification helpers.
- `beamdrop-discovery`: local discovery constants, discovery records, and a
  platform-neutral discovery provider interface.
- `beamdrop-store`: shared entity definitions matching the intended local SQLite
  schema.
- `beamdrop-bindings`: placeholder binding boundary for Kotlin, Swift, and C#.

## Running Tests

From this directory:

```sh
cargo test --workspace
```

This workspace uses standard Rust crates from crates.io for JSON serialization
and SHA-256 hashing. The current execution environment used to create this
foundation did not have `cargo` or `rustc` on PATH, so tests must be run on a
machine with the Rust toolchain installed.
