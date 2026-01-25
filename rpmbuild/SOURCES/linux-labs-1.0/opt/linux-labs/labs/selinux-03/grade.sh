#!/bin/bash

source /opt/linux-labs/lib/colors.sh

err()  { fail "$*"; exit 1; }
ok()   { pass "$*"; }
info() { echo "[INFO] $*"; }

# 1) Ensure SELinux is enabled and enforcing/permissive (not disabled)
if ! sestatus >/dev/null 2>&1; then err "SELinux not available"; fi
SESTATUS=$(getenforce)
if [[ "$SESTATUS" != "Enforcing" && "$SESTATUS" != "Permissive" ]]; then err "SELinux not active (status: $SESTATUS)"; fi
ok "SELinux active: $SESTATUS"

# 2) Verify port 8081 labeled for httpd
if ! command -v semanage >/dev/null 2>&1; then err "semanage not available (install policycoreutils-python-utils)"; fi
if ! semanage port -l | awk '$1=="http_port_t" {print $3}' | tr -d ',' | grep -qx 8081; then
	err "Port 8081 not labeled http_port_t"
fi
ok "Port 8081 labeled as http_port_t"

# 3) Verify content labeled for httpd
CTX=$(ls -Z /webapp/porttest/index.html | awk '{print $1}')
TYPE=$(echo "$CTX" | cut -d: -f3)
if [[ "$TYPE" != "httpd_sys_content_t" ]]; then err "Content not labeled httpd_sys_content_t (got $CTX)"; fi
ok "Content labeled httpd_sys_content_t"

# 4) Verify httpd is running
if ! systemctl is-active --quiet httpd; then err "httpd service not active"; fi
ok "httpd service active"

# 5) Verify content served on 8081
if ! curl -sSf http://localhost:8081/ >/tmp/selinux03.out; then err "Failed to fetch page on 8081"; fi
if ! grep -q "Custom port test page" /tmp/selinux03.out; then err "Unexpected page content on 8081"; fi
ok "Page reachable on 8081"

ok "All checks passed"
