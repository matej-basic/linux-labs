#!/bin/bash
# selinux-02 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/selinux-02
WWW=/webapp/www
MARKER='selinux-02 web application'

grade_begin selinux-02
grade_require_state selinux-02 "$STATE_FILE"

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] &&
		grep -Eq '^SELINUX=enforcing[[:space:]]*$' /etc/selinux/config
}

app_files_exist() {
	[ -f "$WWW/index.html" ] && [ -f /webapp/config/db.conf ] &&
		[ -f /webapp/data/app.log ] && grep -q "$MARKER" "$WWW/index.html"
}

httpd_enabled_running() {
	systemctl is-enabled --quiet httpd && systemctl is-active --quiet httpd
}

vhost_configured() {
	local f=/etc/httpd/conf.d/myapp.conf
	[ -f "$f" ] &&
		grep -Eiq '^[[:space:]]*<VirtualHost[[:space:]]+[^>]*:80>' "$f" &&
		grep -Eiq '^[[:space:]]*ServerName[[:space:]]+localhost[[:space:]]*$' "$f" &&
		grep -Eiq '^[[:space:]]*DocumentRoot[[:space:]]+"?/webapp/www/?"?[[:space:]]*$' "$f"
}

page_served() {
	local out
	out=$(curl -s --max-time 10 --retry 2 -o - -w '\n%{http_code}' http://localhost/ 2>/dev/null) || return 1
	[ "$(printf '%s\n' "$out" | tail -n 1)" = 200 ] &&
		printf '%s\n' "$out" | grep -q "$MARKER"
}

www_type_set() {
	local p
	[ -d "$WWW" ] || return 1
	while IFS= read -r -d '' p; do
		[ "$(stat -c %C "$p" 2>/dev/null | cut -d: -f3)" = httpd_sys_rw_content_t ] || return 1
	done < <(find "$WWW" -print0)
}

www_label_persistent() {
	[ -d "$WWW" ] && [ -z "$(restorecon -nvR "$WWW" 2>&1)" ] &&
		semanage fcontext -l -C 2>/dev/null | grep -q '^/webapp.*httpd_sys_rw_content_t'
}

private_dirs_unlabelled() {
	local p
	[ -d /webapp/config ] && [ -d /webapp/data ] || return 1
	while IFS= read -r -d '' p; do
		stat -c %C "$p" 2>/dev/null | cut -d: -f3 | grep -q '^httpd_' && return 1
	done < <(find /webapp/config /webapp/data -print0)
	return 0
}

criterion "SELinux is enforcing now and in /etc/selinux/config" selinux_enforcing
criterion "Application files in /webapp are in place" app_files_exist
criterion "Package httpd is installed" rpm -q httpd
criterion "httpd is enabled and running" httpd_enabled_running
criterion "Virtual host in myapp.conf serves $WWW on port 80" vhost_configured
criterion "http://localhost/ returns index.html with status 200" page_served
criterion "$WWW and its content are httpd_sys_rw_content_t" www_type_set
criterion "The $WWW label survives a restorecon" www_label_persistent
criterion "/webapp/config and /webapp/data have no httpd_ type" private_dirs_unlabelled
grade_end
