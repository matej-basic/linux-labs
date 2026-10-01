#!/usr/bin/env bash
set -euo pipefail

# Build the GitHub Pages site locally and serve it on localhost.
#
# Usage: scripts/preview-pages.sh [--build-only] [port]
#
# Writes into packaging/site/ (gitignored) the same files the publish job
# puts on gh-pages, through scripts/update-pages.sh --no-rpm. The dnf
# repository under rpm/ is left out. Then serves the directory with
# python3 -m http.server until Ctrl+C. --build-only stops after the build.
# The port defaults to 8000.
#
# pandoc: update-pages.sh uses a local pandoc when there is one, else the
# pandoc/core docker image.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SITE_DIR="$ROOT_DIR/packaging/site"
BUILD_ONLY=false
PORT=8000

for arg in "$@"; do
        case "$arg" in
                --build-only) BUILD_ONLY=true ;;
                -h|--help) sed -n '4,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
                *[!0-9]*|"") echo "Error: unknown argument: $arg" >&2; exit 2 ;;
                *) PORT="$arg" ;;
        esac
done

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR"
"$ROOT_DIR/scripts/update-pages.sh" --no-rpm "$SITE_DIR"

if $BUILD_ONLY; then
        exit 0
fi

echo "==> Serving $SITE_DIR"
echo "    http://localhost:$PORT/  (Ctrl+C to stop)"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$SITE_DIR"
