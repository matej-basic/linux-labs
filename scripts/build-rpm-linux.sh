#!/usr/bin/env bash
set -euo pipefail

# RPM build script for Linux (Rocky, Fedora, RHEL, etc.)
# Requires rpmbuild installed: dnf install rpm-build
#
# Usage: build-rpm-linux.sh [--deploy <user@host>]
#   --deploy <user@host>  copy the built RPM to /root/ on that host over scp
#                         and reinstall it there with dnf. Without this flag
#                         the script does not contact any host.

usage() {
        echo "Usage: $0 [--deploy <user@host>]" >&2
}

DEPLOY_HOST=""
while [[ $# -gt 0 ]]; do
        case "$1" in
                --deploy)
                        if [[ $# -lt 2 || -z "$2" ]]; then
                                echo "Error: --deploy needs a target, e.g. --deploy root@10.0.0.149" >&2
                                exit 1
                        fi
                        DEPLOY_HOST="$2"
                        shift 2
                        ;;
                -h|--help)
                        usage
                        exit 0
                        ;;
                *)
                        echo "Error: unknown argument: $1" >&2
                        usage
                        exit 1
                        ;;
        esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TOPDIR="$ROOT_DIR/packaging/rpmbuild"
SPEC_SOURCE="$ROOT_DIR/rpm/linux-labs.spec"
SPEC="$TOPDIR/SPECS/linux-labs.spec"
LABS_SOURCE="$ROOT_DIR/labs"
SRC_DIR="$ROOT_DIR/src"
ETC_SOURCE="$SRC_DIR/etc"
USR_SOURCE="$SRC_DIR/usr"
OPT_SOURCE="$SRC_DIR/opt"
DOC_SOURCE="$ROOT_DIR/docs/student"

if [[ ! -f "$SPEC_SOURCE" ]]; then
        echo "Error: spec not found at $SPEC_SOURCE" >&2
        exit 1
fi

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

if ! compgen -G "$DOC_SOURCE/*.md" >/dev/null; then
        echo "Error: no student documentation (*.md) in $DOC_SOURCE" >&2
        exit 1
fi

if ! command -v rpmbuild >/dev/null 2>&1; then
        echo "Error: rpmbuild not found. Install with: dnf install rpm-build" >&2
        exit 1
fi

# Name and version come from the spec in git, before any SOURCES path is made
NAME="$(awk '/^Name:/ {print $2; exit}' "$SPEC_SOURCE")"
VERSION="$(awk '/^Version:/ {print $2; exit}' "$SPEC_SOURCE")"

if [[ -z "$NAME" || -z "$VERSION" ]]; then
        echo "Error: could not read Name/Version from $SPEC_SOURCE" >&2
        exit 1
fi

SOURCE_DIR="$TOPDIR/SOURCES/$NAME-$VERSION"
TARBALL="$TOPDIR/SOURCES/$NAME-$VERSION.tar.gz"
LABS_DEST="$SOURCE_DIR/opt/linux-labs/labs"
ETC_DEST="$SOURCE_DIR/etc"
USR_DEST="$SOURCE_DIR/usr"
OPT_DEST="$SOURCE_DIR/opt"
DOC_DEST="$SOURCE_DIR/doc"

echo "==> Building $NAME $VERSION"

# Start from a clean source tree for this version
rm -rf "$SOURCE_DIR" "$TARBALL"
mkdir -p "$SOURCE_DIR/opt/linux-labs" "$TOPDIR/SPECS"

echo "==> Copying spec from $SPEC_SOURCE to $SPEC"
cp "$SPEC_SOURCE" "$SPEC"

echo "==> Syncing labs from $LABS_SOURCE to $LABS_DEST"
cp -r "$LABS_SOURCE" "$LABS_DEST"

# solve.sh (automatic solver for scripts/test-lab.sh) is not shipped
find "$LABS_DEST" -type f -name solve.sh -delete

echo "==> Syncing etc from $ETC_SOURCE to $ETC_DEST"
cp -r "$ETC_SOURCE" "$ETC_DEST"

echo "==> Syncing usr from $USR_SOURCE to $USR_DEST"
cp -r "$USR_SOURCE" "$USR_DEST"

echo "==> Syncing opt from $OPT_SOURCE to $OPT_DEST"
cp -r "$OPT_SOURCE/linux-labs/lib" "$OPT_DEST/linux-labs/"

echo "==> Syncing student docs from $DOC_SOURCE to $DOC_DEST"
mkdir -p "$DOC_DEST"
cp "$DOC_SOURCE"/*.md "$DOC_DEST/"

echo "==> Creating source tarball: $TARBALL"
tar -czf "$TARBALL" -C "$TOPDIR/SOURCES" "$NAME-$VERSION"

# Drop RPMs from earlier builds so the glob below only sees this one
rm -f "$TOPDIR/RPMS/noarch/$NAME-"*.rpm

echo "==> Building RPM..."
rpmbuild -ba --define "_topdir $TOPDIR" "$SPEC"

shopt -s nullglob
RPMS=("$TOPDIR/RPMS/noarch/$NAME-$VERSION-"*.noarch.rpm)
shopt -u nullglob

if [[ ${#RPMS[@]} -ne 1 ]]; then
        echo "Error: expected one RPM in $TOPDIR/RPMS/noarch, found ${#RPMS[@]}" >&2
        exit 1
fi
RPM_FILE="${RPMS[0]}"

echo "==> Done. RPMs in: $TOPDIR/RPMS/noarch"
ls -lh "$RPM_FILE"

if [[ -n "$DEPLOY_HOST" ]]; then
        RPM_BASENAME="$(basename "$RPM_FILE")"
        echo "==> Deploying $RPM_BASENAME to $DEPLOY_HOST"
        scp "$RPM_FILE" "$DEPLOY_HOST:/root/"
        # shellcheck disable=SC2029 # the RPM name is meant to expand locally
        ssh "$DEPLOY_HOST" "dnf -y remove $NAME; dnf -y install /root/$RPM_BASENAME"
fi
