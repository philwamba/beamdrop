# Windows App

This directory contains the BeamDrop Windows foundation.

The Windows app should be built with C#, WinUI 3, and Windows App SDK. The
current implementation keeps transfer, pairing, discovery, clipboard policy,
history, and security logic in a testable `.NET` core library so it can be
validated before the WinUI shell is wired in.

## Projects

- `src/BeamDrop.Windows.Core`: pairing, local discovery records, trusted peers,
  transfer streaming, SHA-256 verification, clipboard policy, audit events, and
  diagnostics.
- `src/BeamDrop.Windows.App`: WinUI-facing view models for tray/menu actions,
  pairing import, diagnostics, settings, and history.
- `tests/BeamDrop.Windows.Tests`: no-package console test runner.

## Build and Test

```sh
dotnet build BeamDrop.Windows.sln
dotnet run --project tests/BeamDrop.Windows.Tests/BeamDrop.Windows.Tests.csproj
```

## Native Shell Projects

This pass also adds the requested top-level native Windows shell projects:

- `BeamDrop.Windows.App`: WinUI 3 desktop shell.
- `BeamDrop.Windows.Tray`: native tray host using `NotifyIcon`.
- `BeamDrop.Windows.Clipboard`: clipboard policy logic.
- `BeamDrop.Windows.Network`: local discovery model and `_beamdrop._tcp` service contract.
- `BeamDrop.Windows.Transfer`: transfer models and trust gate.
- `BeamDrop.Windows.Security`: trusted peer, identity, and secret-store abstractions.
- `BeamDrop.Windows.Persistence`: SQLite schema and repositories.
- `Tests`: portable test runner for policy and persistence logic.

Portable verification:

```sh
dotnet run --project Tests/Tests.csproj
```

On Windows with the WinUI workload and Windows App SDK restored:

```sh
dotnet build BeamDrop.Windows.sln
```
