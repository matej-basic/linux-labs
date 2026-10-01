#!/bin/bash
# networking-02 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/networking-02

grade_begin networking-02
grade_require_state networking-02 "$STATE_FILE"
nic=$(sed -n 1p "$STATE_FILE")

# vlan10 is a NetworkManager VLAN profile with ID 10
profile_is_vlan() {
	[ "$(nmcli -g connection.type connection show vlan10 2>/dev/null)" = vlan ] &&
		[ "$(nmcli -g vlan.id connection show vlan10 2>/dev/null)" = 10 ]
}

# The kernel interface vlan10 is 802.1Q ID 10 on the free NIC
vlan_on_nic() {
	local out
	out=$(ip -d -o link show vlan10 2>/dev/null) || return 1
	printf '%s\n' "$out" | grep -q "^[0-9]*: vlan10@$nic:" &&
		printf '%s\n' "$out" | grep -q 'vlan protocol 802.1Q id 10 '
}

# The profile holds exactly the static address 192.168.10.1/24
profile_address() {
	[ "$(nmcli -g ipv4.method connection show vlan10 2>/dev/null)" = manual ] &&
		[ "$(nmcli -g ipv4.addresses connection show vlan10 2>/dev/null | tr -d ' ')" = 192.168.10.1/24 ]
}

# The interface is up with exactly that IPv4 address
runtime_up() {
	ip -o link show vlan10 2>/dev/null | grep -q '[<,]UP[,>]' &&
		[ "$(ip -4 -o addr show dev vlan10 2>/dev/null | awk '{ print $4 }')" = 192.168.10.1/24 ]
}

static_hostname() {
	[ "$(hostnamectl --static 2>/dev/null)" = labhost ]
}

# labhost.example.com is in /etc/hosts together with the alias labhost
hosts_entry() {
	awk '
		{ sub(/#.*/, "") }
		NF >= 3 {
			fq = 0; al = 0
			for (i = 2; i <= NF; i++) {
				if ($i == "labhost.example.com") fq = 1
				if ($i == "labhost") al = 1
			}
			if (fq && al) found = 1
		}
		END { exit !found }
	' /etc/hosts
}

criterion "Connection vlan10 is a VLAN connection with VLAN ID 10" profile_is_vlan
criterion "Interface vlan10 is VLAN 10 on the free interface $nic" vlan_on_nic
criterion "Connection vlan10 has the static address 192.168.10.1/24" profile_address
criterion "Interface vlan10 is up with address 192.168.10.1/24" runtime_up
criterion "Static hostname is labhost" static_hostname
criterion "labhost.example.com and labhost are in /etc/hosts" hosts_entry
criterion "labhost.example.com resolves locally" getent hosts labhost.example.com
grade_end
