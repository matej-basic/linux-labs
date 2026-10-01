#!/bin/bash
# dns-01 grader
source /opt/linux-labs/lib/grading.sh

listens() {
	[ -n "$(ss -H -ln "$1" 'sport = :53' 2>/dev/null)" ]
}

grade_begin dns-01
criterion "Package bind is installed" rpm -q bind
criterion "Package bind-utils is installed" rpm -q bind-utils
criterion "named is running" systemctl is-active --quiet named
criterion "named is enabled at boot" systemctl is-enabled --quiet named
criterion "Port 53/udp has a listener" listens -u
criterion "Port 53/tcp has a listener" listens -t
grade_end
