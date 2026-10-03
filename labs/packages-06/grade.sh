#!/bin/bash
# packages-06 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/packages-06
REPO_FILE=/etc/yum.repos.d/labrepo.repo

grade_begin packages-06
grade_require_state packages-06 "$STATE_FILE"

EL=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
ARCH=$(uname -m)
BASE="https://dl.rockylinux.org/pub/rocky/$EL"

# The repository configuration as dnf reads it (dnf.conf defaults and
# variables such as $releasever applied), one line per repository:
# id|enabled|baseurl,...|gpgcheck|gpgkey,...|repofile
PY=/usr/libexec/platform-python
[ -x "$PY" ] || PY=python3
REPOS=$("$PY" - 2>/dev/null <<'PYEOF'
import dnf
import dnf.rpm
b = dnf.Base()
try:
    b.conf.read()
except Exception:
    pass
b.conf.substitutions['releasever'] = dnf.rpm.detect_releasever('/')
b.conf.substitutions.update_from_etc('/')
b.read_all_repos()
for r in b.repos.all():
    print('|'.join([r.id, '1' if r.enabled else '0', ','.join(r.baseurl),
                    '1' if r.gpgcheck else '0', ','.join(r.gpgkey),
                    r.repofile or '']))
PYEOF
)

# field <id> <n>: field n of the line of repository <id>
field() {
	printf '%s\n' "$REPOS" | awk -F'|' -v id="$1" -v n="$2" '$1 == id { print $n; exit }'
}

# repo_ok <id> <url>: defined in labrepo.repo, enabled, with exactly
# this base URL (a trailing slash does not matter)
repo_ok() {
	local url
	[ "$(field "$1" 6)" = "$REPO_FILE" ] || return 1
	[ "$(field "$1" 2)" = 1 ] || return 1
	url=$(field "$1" 3)
	[ "${url%/}" = "${2%/}" ]
}

# signed <id>: gpgcheck on and every gpgkey a local file that exists
signed() {
	local keys k
	[ "$(field "$1" 4)" = 1 ] || return 1
	keys=$(field "$1" 5)
	[ -n "$keys" ] || return 1
	for k in ${keys//,/ }; do
		case "$k" in file://*) ;; *) return 1 ;; esac
		[ -f "${k#file://}" ] || return 1
	done
}

only_lab_enabled() {
	local ids
	ids=$(printf '%s\n' "$REPOS" | awk -F'|' '$2 == 1 { print $1 }' | LC_ALL=C sort | tr '\n' ' ')
	[ "$ids" = "lab-appstream lab-baseos " ]
}

# from_repo <package> <repo>: installed, and dnf recorded <repo> as the
# repository it came from
from_repo() {
	rpm -q "$1" >/dev/null 2>&1 || return 1
	[ "$(LC_ALL=C dnf -q --disablerepo='*' repoquery --installed \
		--qf '%{from_repo}' "$1" 2>/dev/null | head -n 1)" = "$2" ]
}

criterion "File $REPO_FILE exists" test -f "$REPO_FILE"
criterion "Repository lab-baseos is enabled with the BaseOS URL" \
	repo_ok lab-baseos "$BASE/BaseOS/$ARCH/os/"
criterion "Repository lab-appstream is enabled with the AppStream URL" \
	repo_ok lab-appstream "$BASE/AppStream/$ARCH/os/"
criterion "lab-baseos checks signatures with an existing key file" signed lab-baseos
criterion "lab-appstream checks signatures with an existing key file" signed lab-appstream
criterion "lab-baseos and lab-appstream are the only enabled repositories" only_lab_enabled
criterion "Package zsh is installed from lab-baseos" from_repo zsh lab-baseos
criterion "Package ksh is installed from lab-appstream" from_repo ksh lab-appstream
grade_end
