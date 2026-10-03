#!/bin/bash
# samba-01 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

DIR=/srv/samba/team
MP=/mnt/team
CRED=/root/team.creds
SUSER=smbuser
GROUP=smbteam

grade_begin samba-01
grade_require_state samba-01

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
SHARE="//$NODE1_IP/team"

for ip in "$NODE1_IP" "$NODE2_IP"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# on <ip> <command>: run a command as root on a node
on() {
	run_on_node "$1" "sudo -n sh -c $(printf '%q' "$2")" </dev/null 2>/dev/null
}

# param <name>: the value testparm reports for a parameter of [team]
param() {
	on "$NODE1_IP" "testparm -s --section-name=team --parameter-name='$1'"
}

smb_ok() {
	on "$NODE1_IP" "systemctl is-enabled smb && systemctl is-active smb"
}

share_path() {
	local p
	p=$(param path) || return 1
	[ "$p" = "$DIR" ] || [ "$p" = "$DIR/" ]
}

share_writable() {
	[ "$(param "read only")" = No ]
}

# valid users names the group (@group, +group, &group or +&group)
share_group() {
	param "valid users" | tr ',' ' ' | tr -s ' ' '\n' |
		grep -qxE "[@+&]{1,2}$GROUP"
}

dir_context() {
	on "$NODE1_IP" "stat -c %C $DIR" | grep -q ':samba_share_t:'
}

# The file context of the policy, local rules included, for the
# directory and a file below it
fcontext_rule() {
	on "$NODE1_IP" "matchpathcon -n $DIR $DIR/file" |
		awk '$0 !~ /:samba_share_t:/ { bad = 1 } { n++ } END { exit (bad || n != 2) }'
}

firewall_ok() {
	on "$NODE1_IP" "firewall-cmd --query-service=samba && firewall-cmd --permanent --query-service=samba"
}

pdb_user() {
	on "$NODE1_IP" "pdbedit -L" | grep -q "^$SUSER:"
}

cred_perms() {
	[ "$(on "$NODE2_IP" "stat -c '%U %a' $CRED")" = "root 600" ]
}

cred_content() {
	local c
	c=$(on "$NODE2_IP" "cat $CRED") || return 1
	printf '%s\n' "$c" | grep -qE "^[[:space:]]*(username|user)[[:space:]]*=[[:space:]]*${SUSER}[[:space:]]*$" &&
		printf '%s\n' "$c" | grep -qE "^[[:space:]]*(password|pass)[[:space:]]*=."
}

# fstab_entry [opts]: /etc/fstab on node 2 mounts the share on the
# mount point as cifs; with "opts" also with the credentials file and
# _netdev
fstab_entry() {
	on "$NODE2_IP" "cat /etc/fstab" |
		awk -v s="$SHARE" -v m="$MP" -v c="$CRED" -v want="${1:-}" '
			$1 !~ /^#/ && ($1 == s || $1 == s "/") && ($2 == m || $2 == m "/") && $3 == "cifs" {
				n = split($4, o, ",")
				cr = 0; nd = 0
				for (i = 1; i <= n; i++) {
					if (o[i] == "credentials=" c || o[i] == "cred=" c) cr = 1
					if (o[i] == "_netdev") nd = 1
				}
				if (want == "" || (cr && nd)) f = 1
			}
			END { exit !f }'
}

mounted() {
	local src fstype
	read -r src fstype < <(on "$NODE2_IP" "findmnt -n -o SOURCE,FSTYPE --mountpoint $MP")
	{ [ "$src" = "$SHARE" ] || [ "$src" = "$SHARE/" ]; } && [ "$fstype" = cifs ]
}

# root on node 2 writes a file in the mount; on node 1 it must belong to
# the Samba user. The file is removed again.
written_owner() {
	local name=".samba-01-grade-$$-$RANDOM" rc=1
	if on "$NODE2_IP" "mountpoint -q $MP && echo samba-01 > $MP/$name"; then
		[ "$(on "$NODE1_IP" "stat -c %U $DIR/$name")" = "$SUSER" ] && rc=0
	fi
	on "$NODE2_IP" "rm -f $MP/$name" >/dev/null
	on "$NODE1_IP" "rm -f $DIR/$name" >/dev/null
	return "$rc"
}

criterion "smb is enabled and running on node 1" smb_ok
criterion "The share [team] has the path $DIR" share_path
criterion "The share [team] is writable" share_writable
criterion "Only the group $GROUP is valid for [team]" share_group
criterion "$DIR has the SELinux type samba_share_t" dir_context
criterion "A file context rule gives $DIR samba_share_t" fcontext_rule
criterion "The firewall on node 1 allows the samba service" firewall_ok
criterion "$SUSER has a Samba account on node 1" pdb_user
criterion "$CRED on node 2 is owned by root, mode 0600" cred_perms
criterion "$CRED holds the credentials of $SUSER" cred_content
criterion "/etc/fstab on node 2 mounts $SHARE on $MP" fstab_entry
criterion "The fstab entry uses $CRED and _netdev" fstab_entry opts
criterion "$SHARE is mounted on $MP as cifs" mounted
criterion "Files written on node 2 belong to $SUSER on node 1" written_owner
grade_end
