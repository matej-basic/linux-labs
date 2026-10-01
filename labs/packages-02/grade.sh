#!/bin/bash
# packages-02 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/packages-02

grade_begin packages-02
grade_require_state packages-02 "$STATE_FILE"

# A [epel] section with enabled=1 (the default when the key is absent)
epel_enabled() {
	cat /etc/yum.repos.d/*.repo 2>/dev/null | awk '
		/^\[/ { if (in_epel && en) found = 1; in_epel = ($0 == "[epel]"); en = 1; next }
		in_epel && /^[[:space:]]*enabled[[:space:]]*=/ {
			v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); en = (v == "1")
		}
		END { if (in_epel && en) found = 1; exit !found }'
}

# dnf records the repository a package was installed from
htop_from_epel() {
	LC_ALL=C dnf -q info installed htop 2>/dev/null |
		awk -F: '/^From repo/ { gsub(/[[:space:]]/, "", $2); r = $2 } END { exit !(r == "epel") }'
}

criterion "Repository epel is enabled" epel_enabled
criterion "Package htop is installed" rpm -q htop
criterion "Package htop was installed from the epel repository" htop_from_epel
criterion "Command htop runs" htop --version
grade_end
