#!/usr/bin/env bash
# Installer for linux-labs on Rocky Linux / RHEL / AlmaLinux 8 and 9.
#
#   curl -fsSL https://matej-basic.github.io/linux-labs/install | sudo bash
#
# Adds the linux-labs dnf repository, imports its signing key and installs
# (or upgrades) the linux-labs package. Everything runs inside main(), which
# is called on the last line, so a partial download does nothing.

set -euo pipefail

BASE_URL="https://matej-basic.github.io/linux-labs"
REPO_URL="$BASE_URL/rpm/"
KEY_URL="$BASE_URL/RPM-GPG-KEY-linux-labs"
REPO_FILE="/etc/yum.repos.d/linux-labs.repo"
OS_RELEASE="/etc/os-release"

die() {
    echo "linux-labs install: $*" >&2
    exit 1
}

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "must run as root. Use: curl -fsSL $BASE_URL/install | sudo bash"
    fi
}

check_os() {
    [[ -r "$OS_RELEASE" ]] || die "cannot read $OS_RELEASE, unsupported system"

    local ID="" ID_LIKE="" VERSION_ID="" PRETTY_NAME=""
    # shellcheck disable=SC1090
    . "$OS_RELEASE"

    local name="${PRETTY_NAME:-${ID:-unknown} ${VERSION_ID:-}}"
    local major="${VERSION_ID%%.*}"

    if [[ " $ID $ID_LIKE " != *rhel* ]]; then
        die "unsupported system: $name. linux-labs supports Rocky Linux, RHEL and AlmaLinux 8 and 9."
    fi

    case "$major" in
        8|9) ;;
        *) die "unsupported version: $name. linux-labs supports EL 8 and 9 only." ;;
    esac

    echo "==> Detected $name"
}

write_repo() {
    echo "==> Writing $REPO_FILE"
    cat > "$REPO_FILE" <<EOF
[linux-labs]
name=linux-labs
baseurl=$REPO_URL
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=$KEY_URL
EOF
    chmod 0644 "$REPO_FILE"
}

import_key() {
    echo "==> Importing signing key from $KEY_URL"
    rpm --import "$KEY_URL"
}

install_package() {
    if rpm -q linux-labs >/dev/null 2>&1; then
        echo "==> linux-labs is installed, upgrading"
        dnf -y upgrade linux-labs
    else
        echo "==> Installing linux-labs"
        dnf -y install linux-labs
    fi
}

main() {
    check_root
    check_os
    write_repo
    import_key
    install_package

    echo
    echo "Installed: $(rpm -q linux-labs)"
    echo
    echo "Next steps:"
    echo "  labctl list"
    echo "  sudo labctl start <lab>"
}

main "$@"
