#!/bin/bash
# Reference solution for replication-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The nodes are reset by labctl reset; no path on this host needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 6 [user]. load-config.sh does not work under "set -u". The
# sql helper gets its statement from its own pipe, so ssh cannot eat the
# script.
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
set -u
N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)
sql() { printf '%s\n' "$2" | run_on_node "$1" "sudo mysql -u root -N"; }

# Step 2
i=0
for ip in "$N1" "$N2" "$N3"; do
  i=$((i + 1))
  printf '[mysqld]\nserver-id=%s\nlog-bin=mysql-bin\n' "$i" |
    run_on_node "$ip" "sudo tee /etc/my.cnf.d/replication.cnf >/dev/null"
  run_on_node "$ip" "sudo systemctl restart mysqld" </dev/null
done

# Step 3
for ip in "$N1" "$N2" "$N3"; do
  run_on_node "$ip" "sudo firewall-cmd --permanent --add-port=3306/tcp" </dev/null
  run_on_node "$ip" "sudo firewall-cmd --reload" </dev/null
done

# Step 4
for ip in "$N1" "$N2" "$N3"; do
  sql "$ip" "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpassword'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"
done

# Step 5
link() {
  local file pos
  read -r file pos _ <<< "$(sql "$2" "SHOW BINARY LOG STATUS" 2>/dev/null || sql "$2" "SHOW MASTER STATUS")"
  sql "$1" "CHANGE REPLICATION SOURCE TO SOURCE_HOST='$2', SOURCE_USER='repl', SOURCE_PASSWORD='replpassword', SOURCE_LOG_FILE='$file', SOURCE_LOG_POS=$pos, GET_SOURCE_PUBLIC_KEY=1; START REPLICA;"
}
link "$N2" "$N1"
link "$N3" "$N2"
link "$N1" "$N3"

# Step 6: wait until all three replicas run both threads
for t in $(seq 30); do
  n=0
  for ip in "$N1" "$N2" "$N3"; do
    n=$((n + $(sql "$ip" "SHOW REPLICA STATUS\\G" | grep -Ec 'Replica_(IO|SQL)_Running: Yes')))
  done
  [ "$n" -eq 6 ] && break
  sleep 1
done
[ "$n" -eq 6 ]
STEPS
