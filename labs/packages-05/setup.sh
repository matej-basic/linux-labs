#!/bin/bash
# packages-05 setup: no joe on the system, neither the RPM nor a source
# install left by an earlier attempt. Prints nothing on success.
set -eu

# First run only: remember joe, the build tools and the repo keys
PRE=/var/tmp/packages-05.pre
if [ ! -f "$PRE" ]; then
	{
		if rpm -q joe &>/dev/null; then echo joe-installed; else echo joe-missing; fi
		if rpm -q gcc make &>/dev/null; then echo build-tools-present; else echo build-tools-missing; fi
		rpm -qa 'gpg-pubkey*' | sort | sed 's/^/key /'
	} > "$PRE"
fi

# The joe RPM would collide with the source install
if rpm -q joe &>/dev/null; then
	dnf -y remove joe &>/dev/null || {
		echo "Error: could not remove the joe package" >&2
		exit 1
	}
fi

# Source install, source tree and tarball of an earlier attempt.
# cleanup.sh never touches files owned by an RPM package.
PACKAGES05_SETUP=1 bash "$(dirname "$0")/cleanup.sh"

# Fail if a joe binary is still there (for example owned by a package
# that is not called joe)
if [ -e /usr/bin/joe ] || [ -e /usr/local/bin/joe ]; then
	echo "Error: a joe binary is still installed and could not be removed" >&2
	exit 1
fi
