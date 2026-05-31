#!/usr/bin/env sh
set -eu

zig fmt --check $(git ls-files '*.zig')
zig build --summary all
zig build test --summary all
zig build smoke --summary all
