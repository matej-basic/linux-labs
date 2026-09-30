#!/usr/bin/env bash
set -euo pipefail

# Sign RPMs with the linux-labs release key. Used by .github/workflows/rpm.yml
# on EL8 (rpm 4.14), but works on any host with rpm-sign and gnupg2.
#
# Usage: sign-rpm.sh <file.rpm>...
#
# Environment:
#   RPM_GPG_PRIVATE_KEY  ASCII-armored private key (required)
#   RPM_GPG_PASSPHRASE   passphrase for that key (required)
#   RPM_GPG_NAME         key to sign with (default: the linux-labs key fingerprint)
#
# The key goes into a temporary GNUPGHOME that is deleted on exit. The
# passphrase is passed to gpg through a 0600 file in that directory and is
# never printed.

RPM_GPG_NAME="${RPM_GPG_NAME:-2C8B8EF02609AF36359D2D7E603E53FE67BA2549}"

if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <file.rpm>..." >&2
        exit 1
fi

if [[ -z "${RPM_GPG_PRIVATE_KEY:-}" ]]; then
        echo "Error: RPM_GPG_PRIVATE_KEY is not set" >&2
        exit 1
fi

if [[ -z "${RPM_GPG_PASSPHRASE:-}" ]]; then
        echo "Error: RPM_GPG_PASSPHRASE is not set" >&2
        exit 1
fi

for tool in gpg rpmsign; do
        if ! command -v "$tool" >/dev/null 2>&1; then
                echo "Error: $tool not found. Install with: dnf install gnupg2 rpm-sign" >&2
                exit 1
        fi
done

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
cleanup() {
        gpgconf --kill gpg-agent >/dev/null 2>&1 || true
        rm -rf "$GNUPGHOME"
}
trap cleanup EXIT

chmod 0700 "$GNUPGHOME"
echo "allow-loopback-pinentry" > "$GNUPGHOME/gpg-agent.conf"

PASSFILE="$GNUPGHOME/passphrase"
( umask 077; printf '%s' "$RPM_GPG_PASSPHRASE" > "$PASSFILE" )

echo "==> Importing signing key"
printf '%s\n' "$RPM_GPG_PRIVATE_KEY" | gpg --batch --quiet --pinentry-mode loopback \
        --passphrase-file "$PASSFILE" --import

if ! gpg --batch --list-secret-keys "$RPM_GPG_NAME" >/dev/null 2>&1; then
        echo "Error: secret key $RPM_GPG_NAME not found after import" >&2
        exit 1
fi

# rpm 4.14 (EL8) has no passphrase option, so the whole gpg command is
# overridden to read the passphrase from a file with loopback pinentry.
SIGN_CMD="%{__gpg} gpg --batch --no-verbose --no-armor --pinentry-mode loopback"
SIGN_CMD+=" --passphrase-file $PASSFILE --digest-algo sha256 --no-secmem-warning"
SIGN_CMD+=" -u \"%{_gpg_name}\" -sbo %{__signature_filename} %{__plaintext_filename}"

for rpm_file in "$@"; do
        echo "==> Signing $rpm_file"
        rpmsign --addsign \
                --define "_gpg_path $GNUPGHOME" \
                --define "_gpg_name $RPM_GPG_NAME" \
                --define "_gpg_digest_algo sha256" \
                --define "__gpg_sign_cmd $SIGN_CMD" \
                "$rpm_file" </dev/null
done

echo "==> Signed $# package(s) with $RPM_GPG_NAME"
