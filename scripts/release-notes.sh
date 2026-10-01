#!/usr/bin/env bash
set -euo pipefail

# Print the CHANGELOG section of one version, for use as GitHub release
# notes. Used by .github/workflows/rpm.yml when a vX.Y.Z tag is pushed.
#
# Usage: release-notes.sh <version>      (for example 2.0.0)
#
# The section starts at a line "## <version> (YYYY-MM-DD)" and ends before
# the next "## " heading. Exits 1 when the version has no section, so a
# release without notes fails before anything is published. Before tagging,
# rename "## Unreleased (X.Y.Z)" to "## X.Y.Z (date)".

if [[ $# -ne 1 || -z "$1" ]]; then
        echo "Usage: $0 <version>" >&2
        exit 2
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CHANGELOG="$ROOT_DIR/CHANGELOG"

if [[ ! -f "$CHANGELOG" ]]; then
        echo "Error: $CHANGELOG not found" >&2
        exit 1
fi

notes="$(awk -v ver="$VERSION" '
        /^## / {
                if (found) exit
                # match "## 2.0.0 (2026-10-02)" exactly on the version
                split($0, w, " ")
                if (w[2] == ver && $0 ~ /\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)$/) { found = 1; next }
        }
        found { print }
' "$CHANGELOG")"

# Drop leading and trailing blank lines
notes="$(printf '%s\n' "$notes" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')"

if [[ -z "$notes" ]]; then
        echo "Error: CHANGELOG has no section \"## $VERSION (YYYY-MM-DD)\"." >&2
        echo "Rename the Unreleased section before tagging v$VERSION." >&2
        exit 1
fi

printf '%s\n' "$notes"
