#!/bin/bash
# webserver-07 setup: a company CA in /srv/lab-ca and the intranet
# content in /srv/intranet, without a web server. The CA is an RSA 2048
# key with a self-signed SHA-256 certificate (ca.key mode 0600 root,
# ca.crt), which the DEFAULT crypto policy of Rocky 9 accepts. The page
# /srv/intranet/index.html has no file context rule under /srv, so it is
# labelled var_t. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), the firewall
# state of https and 443/tcp in the default zone, the service state of
# httpd, the SELinux runtime mode, the local file context rules for
# /srv/intranet and the files under /etc/pki/tls and
# /etc/pki/ca-trust/source. cleanup.sh puts all of it back. A second
# run removes what an earlier attempt added and creates a new CA.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=webserver-07
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
CA=/srv/lab-ca
SITE=/srv/intranet
VHOST=/etc/httpd/conf.d/intranet.conf
FC_LOCAL=/etc/selinux/targeted/contexts/files/file_contexts.local
PKI_DIRS="/etc/pki/tls /etc/pki/ca-trust/source"

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	echo "Error: SELinux is disabled; this lab needs SELinux enabled." >&2
	exit 1
fi
if ! command -v firewall-cmd >/dev/null 2>&1 \
	|| ! systemctl is-active --quiet firewalld 2>/dev/null; then
	echo "Error: firewalld is not running on this machine." >&2
	exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
	echo "Error: openssl is not installed." >&2
	exit 1
fi

pkg_snapshot "$LAB"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# Local file context rules for /srv/intranet, one path per line
fc_rules() {
	[ -r "$FC_LOCAL" ] || return 0
	awk '$1 ~ /^\/srv\/intranet/ { print $1 }' "$FC_LOCAL"
}

# Files, links and directories under the PKI directories
pki_list() {
	# shellcheck disable=SC2086 # word splitting is intended
	find $PKI_DIRS -xdev 2>/dev/null | LC_ALL=C sort
}

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	mkdir -p "$STATE_DIR"
	rm -rf "$REC_DIR"
	mkdir -m 0700 "$REC_DIR"
	pki_list > "$REC_DIR/pki.list"
	zone=$(firewall-cmd --get-default-zone)
	fw_open=
	firewall-cmd --permanent --zone="$zone" --query-service=https >/dev/null 2>&1 \
		&& fw_open="$fw_open p:service:https"
	firewall-cmd --zone="$zone" --query-service=https >/dev/null 2>&1 \
		&& fw_open="$fw_open r:service:https"
	firewall-cmd --permanent --zone="$zone" --query-port=443/tcp >/dev/null 2>&1 \
		&& fw_open="$fw_open p:port:443/tcp"
	firewall-cmd --zone="$zone" --query-port=443/tcp >/dev/null 2>&1 \
		&& fw_open="$fw_open r:port:443/tcp"
	svc_state=
	systemctl is-enabled --quiet httpd 2>/dev/null && svc_state="$svc_state httpd:enabled"
	systemctl is-active --quiet httpd 2>/dev/null && svc_state="$svc_state httpd:active"
	tmp="$STATE_FILE.tmp"
	{
		echo "zone=$zone"
		echo "fw_open=$fw_open"
		echo "services=$svc_state"
		echo "selinux_mode=$(getenforce)"
		echo "fc_rules=$(fc_rules | tr '\n' ' ')"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# Reset what a previous run or the solution left behind
systemctl disable --now httpd >/dev/null 2>&1 || true
systemctl reset-failed httpd >/dev/null 2>&1 || true
rm -f "$VHOST"
rm -rf "$CA" "$SITE"
sed -i '/intranet\.lab\.example/d' /etc/hosts
if command -v semanage >/dev/null 2>&1; then
	before=" $(state_value fc_rules) "
	for p in $(fc_rules); do
		case "$before" in
		*" $p "*) ;;
		*) semanage fcontext -d "$p" >/dev/null 2>&1 || true ;;
		esac
	done
fi
# Keys, certificates, requests and trust anchors added since the first
# start, unless a package owns them
pki_list | LC_ALL=C comm -13 "$REC_DIR/pki.list" - | LC_ALL=C sort -r | while IFS= read -r p; do
	rpm -qf "$p" >/dev/null 2>&1 && continue
	if [ -d "$p" ] && [ ! -L "$p" ]; then
		rmdir "$p" 2>/dev/null || true
	else
		rm -f "$p"
	fi
done
update-ca-trust extract
setenforce 1

if [ -n "$(ss -H -tln 'sport = :443' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 443." >&2
	exit 1
fi

# The company CA: RSA 2048, SHA-256, valid for ten years
mkdir -m 0755 "$CA"
cat > "$CA/ca.cnf" <<'CNF'
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca

[dn]
O = Lab Example
CN = Lab Example Root CA

[v3_ca]
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
CNF
(
	umask 077
	openssl genrsa -out "$CA/ca.key" 2048 >/dev/null 2>&1
)
openssl req -new -x509 -config "$CA/ca.cnf" -key "$CA/ca.key" -sha256 \
	-days 3650 -out "$CA/ca.crt" >/dev/null 2>&1
rm -f "$CA/ca.cnf"
chown root:root "$CA/ca.key" "$CA/ca.crt"
chmod 0600 "$CA/ca.key"
chmod 0644 "$CA/ca.crt"
if ! openssl x509 -in "$CA/ca.crt" -noout >/dev/null 2>&1; then
	echo "Error: could not create the lab CA in $CA." >&2
	exit 1
fi

# The intranet content
mkdir -m 0755 "$SITE"
cat > "$SITE/index.html" <<'HTML'
<html>
<head><title>Lab Example intranet</title></head>
<body>
<p>INTRANET-LAB-EXAMPLE-OK</p>
</body>
</html>
HTML
chmod 0644 "$SITE/index.html"
restorecon -R "$SITE" "$CA"

# The firewall: no https and no 443/tcp in the default zone
zone=$(state_value zone)
for s in service:https port:443/tcp; do
	kind=${s%%:*}
	val=${s#*:}
	firewall-cmd --permanent --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
	firewall-cmd --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
done
exit 0
