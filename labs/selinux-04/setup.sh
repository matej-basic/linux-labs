#!/bin/bash
# selinux-04 setup: Apache with UserDir enabled for the lab user webdev,
# whose ~/public_html holds an index page. The boolean
# httpd_enable_homedirs is off and the home directory is mode 0700, so
# http://localhost/~webdev/ fails. httpd runs but is not enabled.
# Prints nothing on success.
#
# The first run records the boolean, the local boolean customizations,
# the installed policy modules and the httpd service state in the state
# file; cleanup.sh puts the boolean and the service state back and the
# grader compares the module list.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=selinux-04
USR=webdev
CONF=/etc/httpd/conf.d/lab-userdir.conf
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	echo "Error: SELinux is disabled; this lab needs SELinux enabled." >&2
	exit 1
fi

pkg_snapshot "$LAB"

if ! { rpm -q httpd >/dev/null 2>&1 &&
	rpm -q policycoreutils-python-utils >/dev/null 2>&1; }; then
	# dnf reports a repo key import on stderr; show its output only
	# when the install fails
	if ! out=$(dnf -y -q install httpd policycoreutils-python-utils \
		</dev/null 2>&1); then
		printf '%s\n' "$out" >&2
		echo "Error: could not install httpd and" \
			"policycoreutils-python-utils." >&2
		exit 1
	fi
fi

# Record the starting point once; a second run keeps the first answer
if [ ! -r "$STATE_FILE" ]; then
	was_enabled=no
	was_active=no
	systemctl is-enabled --quiet httpd 2>/dev/null && was_enabled=yes
	systemctl is-active --quiet httpd 2>/dev/null && was_active=yes
	bool_now=$(getsebool httpd_enable_homedirs | awk '{ print $3 }')
	bool_local=$(semanage boolean -l -C 2>/dev/null | awk 'NR > 1 && NF { print $1 }' |
		tr '\n' ' ')
	bool_saved=$(semanage boolean -l 2>/dev/null |
		awk '$1 == "httpd_enable_homedirs" { gsub(/[(),]/, " "); print $3 }')
	modules=$(semodule -l | awk '{ print $1 }' | sort | tr '\n' ' ')
	mkdir -p "$STATE_DIR"
	{
		echo "httpd_was_enabled=$was_enabled"
		echo "httpd_was_active=$was_active"
		echo "bool_now=$bool_now"
		echo "bool_saved=$bool_saved"
		echo "bool_local=$bool_local"
		echo "modules=$modules"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

# Reset what a previous run or the solution left behind
systemctl disable --now httpd >/dev/null 2>&1 || true
if id "$USR" >/dev/null 2>&1; then
	pkill -u "$USR" >/dev/null 2>&1 || true
	userdel -r "$USR" >/dev/null 2>&1 || true
fi
rm -rf "/home/${USR:?}" "/var/spool/mail/$USR"
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# The boolean starts off, now and in the policy
if [ "$(semanage boolean -l 2>/dev/null |
	awk '$1 == "httpd_enable_homedirs" { gsub(/[(),]/, " "); print $3 }')" != off ]; then
	setsebool -P httpd_enable_homedirs off
fi
setsebool httpd_enable_homedirs off

# The lab user and its page; the home directory keeps mode 0700
useradd -m "$USR"
mkdir "/home/$USR/public_html"
echo "<html><body><p>webdev personal page</p></body></html>" \
	> "/home/$USR/public_html/index.html"
chown -R "$USR:$USR" "/home/$USR/public_html"
chmod 0700 "/home/$USR" "/home/$USR/public_html"
chmod 0644 "/home/$USR/public_html/index.html"
restorecon -R "/home/$USR"

# UserDir for webdev only; userdir.conf of the package stays as it is
cat > "$CONF" <<'CONF'
# selinux-04: user directories for webdev
<IfModule mod_userdir.c>
    UserDir public_html
    UserDir enabled webdev
</IfModule>
CONF
restorecon "$CONF"

if ! systemctl start httpd >/dev/null 2>&1; then
	echo "Error: httpd does not start." >&2
	exit 1
fi
