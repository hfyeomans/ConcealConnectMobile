#!/usr/bin/env bash
mkdir -p ../lib
set -euo pipefail
cd "$(dirname "$0")/../TunnelCore/masquelib"
RUSTFLAGS="-Cstrip=symbols" \
  cargo lipo --release --features="pkg-config-meta"
lipo -create \
  target/universal/release/libquiche.a \
  -output ../lib/libquiche-universal.a
