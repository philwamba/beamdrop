# BeamDrop Bindings

This crate is the planned native binding boundary for Android, iPhone, macOS,
and Windows.

Current status: bindings are not generated yet.

Planned targets:

- Kotlin for Android.
- Swift for iPhone and macOS.
- C# for Windows.

Expected generation path:

- Kotlin and Swift: likely UniFFI after the protocol, transfer, discovery, and
  store APIs stabilize into FFI-safe shapes.
- C#: likely a C ABI plus C# P/Invoke wrapper or a CsWinRT-compatible facade.

The binding layer must not expose raw private keys. Native apps should receive
safe handles, serializable protocol models, transfer handles, and explicit error
types.
