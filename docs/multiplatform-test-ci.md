# Multi-platform test and CI plan for zfetch

zfetch supports Linux, macOS, and Windows. Correctness needs to be tracked in layers:

1. **Static checks**: `zig fmt --check`, `zig build`, `zig build test`.
2. **Pure unit tests**: command parsing, theme/component parsing, buffer rendering, version-name mapping, logo lookup, and asset invariants.
3. **Fixture tests**: split OS readers from parsers so `/proc`, registry, `sysctl`, `xrandr`, `lspci`, and package output can be tested from checked-in fixtures.
4. **Native smoke tests**: run the built CLI on each GitHub runner and assert stable invariants, not exact machine output.
5. **Cross-target compile checks**: compile representative Linux/macOS/Windows targets to catch import/link regressions.

## Local pre-commit

Run:

```sh
./scripts/check.sh
```

Or on Windows:

```powershell
./scripts/check.ps1
```

Enable the bundled hook with:

```sh
git config core.hooksPath .githooks
chmod +x scripts/check.sh .githooks/pre-commit
```

## CI

The CI workflow should run on pull requests and pushes to `main` with a native matrix:

- `ubuntu-latest`
- `macos-13`
- `macos-latest`
- `windows-latest`

Each runner should:

1. Install the pinned Zig version from `build.zig.zon`.
2. Check formatting.
3. Build.
4. Run unit tests.
5. Run CLI smoke commands:
   - `zfetch --help`
   - `zfetch --list-components`
   - `zfetch --list-themes`
   - `zfetch --component OS`
   - `zfetch --theme minimal`
6. Upload smoke outputs as artifacts.

Release CI should be separate and should upload `zfetch` / `zfetch.exe` plus checksums.

## Current Zig version decision

A direct jump to Zig `0.16.0` fixes the local macOS 26 linker issue, but introduces larger breaking changes in stdlib I/O, filesystem, allocator, timer, and macOS framework `@cImport` handling. The lower-risk upgrade for this CI pass is Zig `0.14.1`; it keeps code changes manageable while moving off `0.13.0`. The remaining macOS 26 local linker issue should be validated separately against GitHub-hosted macOS runners.
