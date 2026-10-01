#!/bin/bash
# Reference solution for replication-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The nodes are reset by labctl reset; no path on this host needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 7 [user]. load-config.sh does not work under "set -u".
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
set -u
N1=$(get_node_ip 1); N2=$(get_node_ip 2)
sql() { echo "$2" | run_on_node "$1" "sudo mysql"; }
rn() { run_on_node "$@" </dev/null; }

# Step 2
CNF='[mysqld]\nlog-bin=mysql-bin\nserver-id=1\n'
printf '%b' "$CNF" | run_on_node "$N1" "sudo tee /etc/my.cnf.d/replication.cnf" >/dev/null
rn "$N1" "sudo systemctl restart mysqld"

# Step 3
rn "$N1" "sudo firewall-cmd --permanent --add-service=mysql"
rn "$N1" "sudo firewall-cmd --reload"

# Step 4
sql "$N1" "CREATE USER 'repl'@'%' IDENTIFIED BY 'replpassword';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"

# Step 5
STATUS=$(sql "$N1" "SHOW BINARY LOG STATUS" 2>/dev/null ||
  sql "$N1" "SHOW MASTER STATUS")
LOGFILE=$(echo "$STATUS" | awk 'NR == 2 { print $1 }')
LOGPOS=$(echo "$STATUS" | awk 'NR == 2 { print $2 }')

# Step 6
CNF='[mysqld]\nserver-id=2\nrelay-log=relay-bin\n'
printf '%b' "$CNF" | run_on_node "$N2" "sudo tee /etc/my.cnf.d/replication.cnf" >/dev/null
rn "$N2" "sudo systemctl restart mysqld"

# Step 7
sql "$N2" "CHANGE REPLICATION SOURCE TO SOURCE_HOST='$N1',
SOURCE_USER='repl', SOURCE_PASSWORD='replpassword',
SOURCE_LOG_FILE='$LOGFILE', SOURCE_LOG_POS=$LOGPOS,
GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;"
STEPS
