#!/bin/bash
# firewall-03 grader
source /opt/linux-labs/lib/grading.sh

SVC=custom-app
SVC_FILE=/etc/firewalld/services/custom-app.xml
FWD="port=8443:proto=tcp:toport=443:toaddr="
DESC="Sample Custom Application Service"

grade_begin firewall-03
grade_require_state firewall-03

firewalld_up() {
	systemctl is-enabled --quiet firewalld && systemctl is-active --quiet firewalld
}

# Exact line match in a space-separated list
has_word() {
	tr ' ' '\n' | grep -qxF -- "$1"
}

# Forward-port list: one rule per line in some versions, space-separated
# in others
forward_ok() {
	tr ' ' '\n' | grep -qxF -- "$FWD"
}
forward_permanent() {
	firewall-cmd --permanent --zone=public --list-forward-ports | forward_ok
}
forward_runtime() {
	firewall-cmd --zone=public --list-forward-ports | forward_ok
}

service_ports_ok() {
	[ "$(firewall-cmd --permanent --service=$SVC --get-ports | tr ' ' '\n' | sort | tr '\n' ' ')" = "9090/tcp 9090/udp " ]
}

service_description_ok() {
	[ "$(firewall-cmd --permanent --service=$SVC --get-description | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" = "$DESC" ]
}

public_has() {
	firewall-cmd "${@:2}" --zone=public --list-services | has_word "$1"
}

runtime_matches() {
	firewall-cmd --zone=internal --query-masquerade >/dev/null &&
		forward_runtime &&
		public_has $SVC &&
		public_has http
}

criterion "firewalld is enabled and running" firewalld_up
criterion "Masquerading is enabled in the internal zone" \
	firewall-cmd --permanent --zone=internal --query-masquerade
criterion "Public zone forwards TCP port 8443 to port 443" forward_permanent
criterion "File $SVC_FILE exists" test -f "$SVC_FILE"
criterion "Service $SVC defines ports 9090/tcp and 9090/udp" service_ports_ok
criterion "Service $SVC has the required description" service_description_ok
criterion "Public zone allows the $SVC service" public_has $SVC --permanent
criterion "Public zone allows the http service" public_has http --permanent
criterion "The rules are also active in the running firewall" runtime_matches
grade_end
