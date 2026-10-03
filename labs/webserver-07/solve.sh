#!/bin/bash
# Reference solution for webserver-07, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package httpd
# solve: package mod_ssl
# solve: package policycoreutils-python-utils
# solve: path /srv/lab-ca
# solve: path /srv/intranet
# solve: path /etc/httpd/conf.d/intranet.conf
# solve: path /etc/pki/tls/private/intranet.lab.example.key
# solve: path /etc/pki/tls/certs/intranet.lab.example.crt
# solve: path /etc/pki/ca-trust/source/anchors/lab-example-ca.crt
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q httpd >/dev/null || dnf -y install httpd >/dev/null
rpm -q mod_ssl >/dev/null || dnf -y install mod_ssl >/dev/null
rpm -q policycoreutils-python-utils >/dev/null ||
	dnf -y install policycoreutils-python-utils >/dev/null

# Step 2 [sudo]
openssl req -new -newkey rsa:2048 -nodes \
	-keyout /etc/pki/tls/private/intranet.lab.example.key \
	-out /srv/lab-ca/intranet.lab.example.csr \
	-subj "/O=Lab Example/CN=intranet.lab.example" 2>/dev/null
chmod 0600 /etc/pki/tls/private/intranet.lab.example.key

# Step 3 [sudo]
tee /srv/lab-ca/intranet.ext >/dev/null <<'EXT'
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:intranet.lab.example, DNS:servera
EXT
openssl x509 -req -in /srv/lab-ca/intranet.lab.example.csr \
	-CA /srv/lab-ca/ca.crt -CAkey /srv/lab-ca/ca.key \
	-CAcreateserial -days 730 -sha256 \
	-extfile /srv/lab-ca/intranet.ext \
	-out /etc/pki/tls/certs/intranet.lab.example.crt 2>/dev/null
openssl verify -CAfile /srv/lab-ca/ca.crt \
	/etc/pki/tls/certs/intranet.lab.example.crt

# Step 4 [sudo]
semanage fcontext -a -t httpd_sys_content_t '/srv/intranet(/.*)?'
restorecon -Rv /srv/intranet

# Step 5 [sudo]
tee /etc/httpd/conf.d/intranet.conf >/dev/null <<'CONF'
<VirtualHost *:443>
  ServerName intranet.lab.example
  DocumentRoot /srv/intranet
  SSLEngine on
  SSLCertificateFile /etc/pki/tls/certs/intranet.lab.example.crt
  SSLCertificateKeyFile /etc/pki/tls/private/intranet.lab.example.key
  <Directory /srv/intranet>
    Options None
    AllowOverride None
    Require all granted
  </Directory>
</VirtualHost>
CONF
systemctl enable --now httpd
apachectl configtest

# Step 6 [sudo]
dev=$(ip -4 route show default | awk '{ print $5; exit }')
addr=$(ip -4 -o addr show dev "$dev" |
	awk '{ split($4, a, "/"); print a[1]; exit }')
echo "$addr intranet.lab.example" >> /etc/hosts

# Step 7 [sudo]
cp /srv/lab-ca/ca.crt /etc/pki/ca-trust/source/anchors/lab-example-ca.crt
update-ca-trust extract

# Step 8 [sudo]
firewall-cmd --add-service=https
firewall-cmd --permanent --add-service=https

# Step 9 [user]
for _ in 1 2 3 4 5; do
	run_as_student "curl -s https://intranet.lab.example/ | grep INTRANET-LAB-EXAMPLE-OK" && break
	sleep 1
done
