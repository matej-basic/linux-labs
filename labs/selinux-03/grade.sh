#!/bin/bash
# selinux-03 grader
source /opt/linux-labs/lib/grading.sh

CONTENT=/webapp/porttest

port_labeled() {
	semanage port -l | awk '$1 == "http_port_t" && $2 == "tcp" {
		$1 = ""; $2 = ""; gsub(",", " "); print
	}' | tr -s ' ' '\n' | grep -qx 8081
}

# Type of the path in the policy, and the type it has right now
policy_type_ok() {
	[ "$(matchpathcon -n "$1" 2>/dev/null | cut -d: -f3)" = httpd_sys_content_t ]
}
current_type_ok() {
	[ "$(stat -c %C "$1" 2>/dev/null | cut -d: -f3)" = httpd_sys_content_t ]
}
content_policy_ok() {
	policy_type_ok "$CONTENT" && policy_type_ok "$CONTENT/index.html"
}
content_current_ok() {
	current_type_ok "$CONTENT" && current_type_ok "$CONTENT/index.html"
}

not_permissive() {
	! semanage permissive -l 2>/dev/null | grep -qw httpd_t
}

listening() {
	ss -H -ltn 'sport = :8081' | grep -q .
}

page_served() {
	curl -sf --max-time 10 http://localhost:8081/ | grep -q "Custom port test page"
}

grade_begin selinux-03
grade_require_state selinux-03

criterion "SELinux is in enforcing mode" test "$(getenforce)" = Enforcing
criterion "Domain httpd_t is not a permissive domain" not_permissive
criterion "Port 8081/tcp is labeled http_port_t" port_labeled
criterion "Policy labels $CONTENT content httpd_sys_content_t" content_policy_ok
criterion "$CONTENT content has type httpd_sys_content_t" content_current_ok
criterion "httpd is running" systemctl is-active --quiet httpd
criterion "httpd listens on TCP port 8081" listening
criterion "Page on port 8081 contains \"Custom port test page\"" page_served
grade_end
