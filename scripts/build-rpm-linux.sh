#!/usr/bin/env bash
set -euo pipefail

# RPM build script for Linux (Rocky, Fedora, RHEL, etc.)
# Requires rpmbuild installed: dnf install rpm-build

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TOPDIR="$ROOT_DIR/packaging/rpmbuild"
SPEC="$TOPDIR/SPECS/linux-labs.spec"
LABS_SOURCE="$ROOT_DIR/labs"
SRC_DIR="$ROOT_DIR/src"
ETC_SOURCE="$SRC_DIR/etc"
USR_SOURCE="$SRC_DIR/usr"
OPT_SOURCE="$SRC_DIR/opt"
LABS_DEST="$TOPDIR/SOURCES/linux-labs-1.0/opt/linux-labs/labs"
ETC_DEST="$TOPDIR/SOURCES/linux-labs-1.0/etc"
USR_DEST="$TOPDIR/SOURCES/linux-labs-1.0/usr"
OPT_DEST="$TOPDIR/SOURCES/linux-labs-1.0/opt"

# Create necessary directories
mkdir -p "$TOPDIR/SOURCES/linux-labs-1.0/opt/linux-labs" "$TOPDIR/SPECS"

if [[ ! -d "$LABS_SOURCE" ]]; then
        echo "Error: labs source directory not found: $LABS_SOURCE" >&2
        exit 1
fi

if [[ ! -d "$SRC_DIR" ]]; then
        echo "Error: src directory not found: $SRC_DIR" >&2
        exit 1
fi

if [[ ! -d "$ETC_SOURCE" ]]; then
        echo "Error: etc source directory not found: $ETC_SOURCE" >&2
        exit 1
fi

if [[ ! -d "$USR_SOURCE" ]]; then
        echo "Error: usr source directory not found: $USR_SOURCE" >&2
        exit 1
fi

if [[ ! -d "$OPT_SOURCE" ]]; then
        echo "Error: opt source directory not found: $OPT_SOURCE" >&2
        exit 1
fi

if [[ ! -f "$SPEC" ]]; then
        echo "Error: spec not found at $SPEC" >&2
        exit 1
fi

if ! command -v rpmbuild >/dev/null 2>&1; then
        echo "Error: rpmbuild not found. Install with: dnf install rpm-build" >&2
        exit 1
fi

echo "==> Syncing labs from $LABS_SOURCE to $LABS_DEST"
rm -rf "$LABS_DEST"
cp -r "$LABS_SOURCE" "$LABS_DEST"

echo "==> Syncing etc from $ETC_SOURCE to $ETC_DEST"
rm -rf "$ETC_DEST"
cp -r "$ETC_SOURCE" "$ETC_DEST"

echo "==> Syncing usr from $USR_SOURCE to $USR_DEST"
rm -rf "$USR_DEST"
cp -r "$USR_SOURCE" "$USR_DEST"

echo "==> Syncing opt from $OPT_SOURCE to $OPT_DEST"
rm -rf "$OPT_DEST/linux-labs/lib"
mkdir -p "$OPT_DEST/linux-labs"
cp -r "$OPT_SOURCE/linux-labs/lib" "$OPT_DEST/linux-labs/"

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

scp "$TOPDIR/RPMS/noarch/"*.rpm root@10.0.0.149:/root/
ssh root@10.0.0.149 'dnf -y remove linux-labs ; dnf install -y /root/linux-labs-1.0-1.el8.noarch.rpm'