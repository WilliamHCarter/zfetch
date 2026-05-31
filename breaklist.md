# Zig 0.16 migration break list

Status: resolved for the current migration pass.

## Validation

Environment:

```text
zig version => 0.16.0
```

Completed local checks:

```sh
./scripts/check.sh

zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseSafe --summary all
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSafe --summary all
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseSafe --summary all
zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseSafe --summary all
zig build -Dtarget=x86_64-macos -Doptimize=ReleaseSafe --summary all
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseSafe --summary all
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSafe --summary all
```

Results:

- Native macOS Debug build: passed.
- Native tests: passed, `18/18`.
- Native smoke help: passed.
- Cross-target ReleaseSafe compiles listed above: passed.

## Resolved breakages

- Build system migrated to Zig 0.16 `root_module` / explicit module APIs.
- Embedded theme/logo generated imports wired through Zig 0.16 module imports.
- Managed dynamic lists migrated to `std.array_list.Managed` where allocator ownership is required.
- Entry point and process args migrated to Zig 0.16 process initialization.
- Command execution migrated off removed `std.process.Child.init` while preserving real command execution.
- Environment lookup centralized in `src/utils/env.zig`.
- Filesystem reads/directory iteration migrated to `std.Io.Dir` APIs.
- Stdout rendering migrated to Zig 0.16 `std.Io.File.stdout().writer(...)`.
- ArrayList writer usages replaced with `Managed.print(...)` or direct writer-compatible calls.
- Timer implementation migrated off removed/changed timer APIs with platform-specific monotonic clocks.
- macOS broad framework `@cImport` usage replaced with narrow extern declarations or command-based fetches where appropriate.
- Windows broad `windows.h` `@cImport` usage replaced with narrow extern declarations/types.
- Windows registry access migrated away from removed `std.os.windows.advapi32` namespace access.
- macOS cross-target framework/library search paths added for local SDK-based cross compiles.

## Remaining notes

- Keep validating on real GitHub-hosted Linux/macOS/Windows runners because local cross-compiles cannot exercise platform runtime behavior.
- Do not reintroduce broad platform header `@cImport` usage unless it is proven compatible with Zig 0.16 ReleaseSafe builds.
