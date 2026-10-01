#!/bin/bash
# webserver-01 grader
source /opt/linux-labs/lib/grading.sh

# httpd itself holds a listening socket on TCP port 80
httpd_listens_on_80() {
	ss -H -tlnp 'sport = :80' 2>/dev/null | grep -q '"httpd"'
}

# Apache answers an HTTP request on localhost port 80 (any status code)
http_answers() {
	local code
	code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' http://localhost:80/ 2>/dev/null) || return 1
	[ -n "$code" ] && [ "$code" != 000 ]
}

grade_begin webserver-01
criterion "Package httpd is installed" rpm -q httpd
criterion "httpd is enabled" systemctl is-enabled --quiet httpd
criterion "httpd is running" systemctl is-active --quiet httpd
criterion "httpd listens on TCP port 80" httpd_listens_on_80
criterion "http://localhost answers on port 80" http_answers
grade_end
