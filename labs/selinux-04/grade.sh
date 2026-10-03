#!/bin/bash
# selinux-04 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/selinux-04
HOME_DIR=/home/webdev
WEB=$HOME_DIR/public_html
MARKER='webdev personal page'

page_served() {
	local out
	out=$(curl -s --max-time 10 -o - -w '\n%{http_code}' \
		http://localhost/~webdev/ 2>/dev/null) || return 1
	[ "$(printf '%s\n' "$out" | tail -n 1)" = 200 ] &&
		printf '%s\n' "$out" | grep -q "$MARKER"
}

bool_runtime_on() {
	[ "$(getsebool httpd_enable_homedirs 2>/dev/null | awk '{ print $3 }')" = on ]
}

# semanage boolean -l prints (current , persistent) for each boolean
bool_persistent_on() {
	[ "$(semanage boolean -l 2>/dev/null |
		awk '$1 == "httpd_enable_homedirs" { gsub(/[(),]/, " "); print $3 }')" = on ]
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] &&
		grep -Eq '^SELINUX=enforcing[[:space:]]*$' /etc/selinux/config
}

# Modules that are loaded now and were not loaded at the first start
new_modules() {
	local before m
	before=$(sed -n 's/^modules=//p' "$STATE_FILE")
	for m in $(semodule -l 2>/dev/null | awk '{ print $1 }'); do
		case " $before " in
		*" $m "*) ;;
		*) echo "$m" ;;
		esac
	done
}

no_permissive_added() {
	! semanage permissive -l 2>/dev/null | grep -qw httpd_t || return 1
	! new_modules | grep -q '^permissive_'
}

no_modules_added() {
	! new_modules | grep -vq '^permissive_'
}

# Others may only search the home directory; group and others may not
# write it
home_mode_ok() {
	local m
	m=$(stat -c %a "$HOME_DIR" 2>/dev/null) || return 1
	m=${m: -3}
	case ${m:1:1} in 2 | 3 | 6 | 7) return 1 ;; esac
	[ "${m:2:1}" = 1 ]
}

# Nothing in public_html is writable by group or others
web_not_writable() {
	[ -d "$WEB" ] || return 1
	[ -z "$(find "$WEB" -perm /022 -print -quit 2>/dev/null)" ]
}

httpd_enabled_running() {
	systemctl is-enabled --quiet httpd && systemctl is-active --quiet httpd
}

grade_begin selinux-04
grade_require_state selinux-04 "$STATE_FILE"

criterion "http://localhost/~webdev/ returns the webdev page" page_served
criterion "Boolean httpd_enable_homedirs is on now" bool_runtime_on
criterion "Boolean httpd_enable_homedirs is on persistently" bool_persistent_on
criterion "SELinux is enforcing now and in /etc/selinux/config" selinux_enforcing
criterion "No permissive domains were added" no_permissive_added
criterion "No policy modules were added" no_modules_added
criterion "Others may only search $HOME_DIR, group may not write" home_mode_ok
criterion "No file in $WEB is group or world writable" web_not_writable
criterion "httpd is enabled and running" httpd_enabled_running
grade_end
