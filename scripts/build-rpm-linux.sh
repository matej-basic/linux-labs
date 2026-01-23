#!/usr/bin/env bash
set -euo pipefail

# RPM build script for Linux (Rocky, Fedora, RHEL, etc.)
# Requires rpmbuild installed: dnf install rpm-build

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TOPDIR="$ROOT_DIR/rpmbuild"
SPEC="$TOPDIR/SPECS/linux-labs.spec"

if [[ ! -f "$SPEC" ]]; then
        echo "Error: spec not found at $SPEC" >&2
        exit 1
fi

if ! command -v rpmbuild >/dev/null 2>&1; then
        echo "Error: rpmbuild not found. Install with: dnf install rpm-build" >&2
        exit 1
fi

NAME="$(grep '^Name:' "$SPEC" | awk '{print $2}')"
VERSION="$(grep '^Version:' "$SPEC" | awk '{print $2}')"
SOURCE_DIR="$TOPDIR/SOURCES/$NAME-$VERSION"
TARBALL="$TOPDIR/SOURCES/$NAME-$VERSION.tar.gz"

if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "Error: source dir not found: $SOURCE_DIR" >&2
        exit 1
fi

echo "==> Creating source tarball: $TARBALL"
tar -czf "$TARBALL" -C "$TOPDIR/SOURCES" "$NAME-$VERSION"

echo "==> Building RPM..."
rpmbuild -ba --define "_topdir $TOPDIR" "$SPEC"

echo "==> Done. RPMs in: $TOPDIR/RPMS/noarch"
ls -lh "$TOPDIR/RPMS/noarch/"*.rpm