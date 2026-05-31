$ErrorActionPreference = "Stop"

$zigFiles = git ls-files "*.zig"
zig fmt --check $zigFiles
zig build --summary all
zig build test --summary all
zig build smoke --summary all
