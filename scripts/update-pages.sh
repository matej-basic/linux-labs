#!/usr/bin/env bash
set -euo pipefail

# Add signed RPMs to a checkout of the gh-pages branch and refresh the dnf
# repo metadata. Used by .github/workflows/rpm.yml; git commit and push are
# left to the caller.
#
# Usage: update-pages.sh <gh-pages dir> <signed.rpm>...
#
# Layout written into <gh-pages dir>:
#   rpm/*.rpm, rpm/repodata/   dnf repository (every released RPM is kept)
#   install                    copy of install.sh
#   linux-labs.repo            .repo file for manual installs
#   RPM-GPG-KEY-linux-labs     public signing key
#   index.html, .nojekyll

if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <gh-pages dir> <signed.rpm>..." >&2
        exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SITE_DIR="$1"
shift

if [[ ! -d "$SITE_DIR" ]]; then
        echo "Error: gh-pages directory not found: $SITE_DIR" >&2
        exit 1
fi

if ! command -v createrepo_c >/dev/null 2>&1; then
        echo "Error: createrepo_c not found" >&2
        exit 1
fi

mkdir -p "$SITE_DIR/rpm"
for rpm_file in "$@"; do
        echo "==> Adding $(basename "$rpm_file") to $SITE_DIR/rpm/"
        cp "$rpm_file" "$SITE_DIR/rpm/"
done

if [[ -d "$SITE_DIR/rpm/repodata" ]]; then
        echo "==> Updating repo metadata"
        createrepo_c --update "$SITE_DIR/rpm"
else
        echo "==> Creating repo metadata"
        createrepo_c "$SITE_DIR/rpm"
fi

cp "$ROOT_DIR/install.sh" "$SITE_DIR/install"
cp "$ROOT_DIR/RPM-GPG-KEY-linux-labs" "$SITE_DIR/RPM-GPG-KEY-linux-labs"
cp "$ROOT_DIR/pages/index.html" "$SITE_DIR/index.html"
cp "$ROOT_DIR/pages/linux-labs.repo" "$SITE_DIR/linux-labs.repo"
touch "$SITE_DIR/.nojekyll"

echo "==> gh-pages content ready in $SITE_DIR"
