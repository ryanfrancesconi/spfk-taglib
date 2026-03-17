#!/bin/bash
# Regenerate include/taglib/ symlinks from colocated headers.
# Run from the spfk-taglib repo root.
#
# This script reads the module.modulemap to determine which headers are public,
# finds their physical locations in the source subdirectories, and creates
# relative symlinks in include/taglib/ pointing to each one.
#
# Usage: ./scripts/update-symlinks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/Sources/taglib"
INCLUDE_DIR="$SOURCE_DIR/include/taglib"
MODULEMAP="$SOURCE_DIR/include/module.modulemap"

if [ ! -f "$MODULEMAP" ]; then
    echo "Error: module.modulemap not found at $MODULEMAP"
    exit 1
fi

# Parse header names from the modulemap
# Matches both: header "taglib/foo.h" and textual header "taglib/foo.tcc"
headers=$(grep -oE '(header|textual header) "taglib/[^"]+"' "$MODULEMAP" \
    | sed 's/.*"taglib\///' | sed 's/"//')

# Remove existing symlinks (safety: only symlinks, not regular files)
find "$INCLUDE_DIR" -maxdepth 1 -type l -delete

created=0
missing=0

for header in $headers; do
    # Find the physical file (exclude include/ and utfcpp/ directories)
    physical=$(find "$SOURCE_DIR" -name "$header" \
        -not -path "*/include/*" \
        -not -path "*/utfcpp/*" \
        -type f \
        | head -1)

    if [ -z "$physical" ]; then
        echo "WARNING: No physical file found for $header"
        missing=$((missing + 1))
        continue
    fi

    # Compute relative path from include/taglib/ to the physical file
    relative=$(python3 -c "
import os.path
print(os.path.relpath('$physical', '$INCLUDE_DIR'))
")

    ln -s "$relative" "$INCLUDE_DIR/$header"
    created=$((created + 1))
done

echo "Created $created symlinks in include/taglib/"
if [ "$missing" -gt 0 ]; then
    echo "WARNING: $missing headers listed in modulemap but not found in source tree"
    exit 1
fi
