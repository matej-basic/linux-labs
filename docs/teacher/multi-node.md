# Multi-node labs

Nine labs use extra machines, called nodes, next to the student's workstation:

| Labs | Nodes | Topic |
|---|---|---|
| lb-01, lb-02, lb-03 | 3 | HAProxy, Nginx and keepalived load balancing |
| replication-01, replication-02 | 2 | MySQL and PostgreSQL replication |
| replication-03 | 3 | MySQL multi-master replication |
| clustering-01, clustering-02, clustering-03 | 3 | Pacemaker and Corosync cluster, fencing, quorum |

The student works on the workstation and reaches the nodes over SSH. linux-labs is installed only on the workstation. `labctl start`, `labctl grade` and `labctl reset` run there and log in to the nodes with SSH to prepare, check and clean them. The nodes need Rocky Linux or RHEL 8 or 9, SSH, and access to the package repositories.

The task of each of these labs has a `TOPOLOGY` section that draws the machines with their real addresses.

## What to set up

1. Nodes that the workstation reaches over SSH.
2. An SSH key that works for both root and the student on the workstation (see "SSH access").
3. The lab configuration on the workstation: multi-node labs enabled, the number of nodes, and the node addresses if they do not follow the default pattern.

## The configuration file

labctl and the lab scripts read one file:

- `/etc/linux-labs/config` when it exists, for every user on the VM
- otherwise `~/.config/linux-labs/config` of the user who runs labctl. Under sudo that is the home directory of the user who called sudo, so `sudo labctl start` and the grader read the same file that `labctl configure` wrote for `student`.

The two files are never merged. Once `/etc/linux-labs/config` exists, the user files are ignored.

`labctl configure` writes to whichever file is in use. It does not create `/etc/linux-labs/config` by itself: without that file even `sudo labctl configure` writes to the calling user's `~/.config/linux-labs/config`. To use one system-wide file, which is easier to prepare in a VM template, create it from the installed template first:

```bash
sudo cp /etc/linux-labs/config.template /etc/linux-labs/config
sudo labctl configure set NODES_ENABLED true
sudo labctl configure set NODE_COUNT 3
```

After that every change to it needs sudo; without root labctl stops with `Error: cannot write /etc/linux-labs/config. Use: sudo labctl configure ...`.

Any `labctl configure` action creates the file with default values if it does not exist yet. `labctl configure list` ends with a `Config file:` line that shows which file is in use.

### Settings and defaults

| Setting | Default | Meaning |
|---|---|---|
| `LAB_NETWORK` | `172.25.250.0/24` | network the node addresses are derived from |
| `LAB_GATEWAY` | `172.25.250.254` | gateway of that network |
| `LAB_DNS` | `8.8.8.8` | DNS server |
| `NODES_ENABLED` | `false` | must be `true` for any multi-node lab |
| `NODE_COUNT` | `1` | number of nodes |
| `NODE_IPS` | empty | static node addresses, separated by spaces |
| `SSH_KEY_PATH` | `$HOME/.ssh/id_rsa` | private key used to reach the nodes |
| `SSH_USER` | `opsadmin` | user on the nodes |
| `SSH_PORT` | `22` | SSH port on the nodes |
| `DOCKER_ENABLED` | `false` | reserved, no lab uses it |

The defaults match the Red Hat classroom, where servera, serverb and serverc are 172.25.250.10, .11 and .12.

### Precedence

For each setting the lab scripts take, in this order:

1. an environment variable of the same name
2. the value in the configuration file
3. the default from the table above

sudo resets the environment, and `labctl start`, `labctl grade` and `labctl reset` always run through sudo. In practice the file and the defaults decide. Environment variables only count when you call labctl from a root shell, or for `labctl task`, which runs as the student and fills the node addresses into the task text.

## Node addresses

With `NODE_IPS` empty, node N gets the address `<network base>.<N+9>`, where the network base is `LAB_NETWORK` without its last number:

| LAB_NETWORK | node 1 | node 2 | node 3 |
|---|---|---|---|
| `172.25.250.0/24` (default) | 172.25.250.10 | 172.25.250.11 | 172.25.250.12 |
| `10.0.0.0/24` | 10.0.0.10 | 10.0.0.11 | 10.0.0.12 |

When the nodes have other addresses, list them in `NODE_IPS`, separated by spaces, node 1 first. They can be anywhere, also in different networks:

```bash
sudo labctl configure set NODE_IPS "10.0.0.189 10.0.0.190 10.0.0.191"
sudo labctl configure set NODE_COUNT 3
```

When `NODE_IPS` is set it replaces the derived addresses completely. `configure set` does not count the addresses, so set `NODE_COUNT` to match. The task text shows `(node N not configured)` for every node above `NODE_COUNT`.

Use spaces, not commas. labctl does not check that the entries are valid IPv4 addresses.

To go back to derived addresses, run the wizard and choose option 1, or edit the file and set `NODE_IPS=""`. `labctl configure set NODE_IPS ""` does not work: `set` refuses an empty value.

## labctl configure

| Command | What it does |
|---|---|
| `labctl configure interactive` | wizard: multi-node on or off, number of nodes, derived or static addresses, network, gateway, DNS |
| `labctl configure list` | prints the settings and the file in use |
| `labctl configure set KEY VALUE` | sets one setting |
| `labctl configure validate` | checks the format of `LAB_NETWORK`, `LAB_GATEWAY` and `LAB_DNS` |
| `labctl configure reset` | deletes the file and writes it again with the defaults |

Prefix each with `sudo` when you use `/etc/linux-labs/config`.

Three details:

- The wizard always writes the SSH settings back to their defaults (`$HOME/.ssh/id_rsa`, `opsadmin`, `22`). Run `configure set` for `SSH_KEY_PATH`, `SSH_USER` or `SSH_PORT` after the wizard, not before.
- With static addresses the wizard sets `NODE_COUNT` to the number of addresses you typed.

`validate` checks nothing about the nodes. It does not look at `NODE_IPS` and does not try to connect.

A typical setup for the Red Hat classroom, as `student` on the workstation:

```bash
sudo labctl configure interactive
```

```
Enable multi-node labs? (y/n) [n]: y
Number of nodes? [3]: 3
...
Choose option [1]: 1
IPs will be auto-calculated from 172.25.250.0/24
Lab network [172.25.250.0/24]:
Gateway IP [172.25.250.254]:
DNS server [8.8.8.8]:

Configuration saved to /home/student/.config/linux-labs/config
```

Then check it:

```bash
labctl configure list
```

```
Current Lab Configuration:
==========================
Network: 172.25.250.0/24
Gateway: 172.25.250.254
DNS: 8.8.8.8
Multi-node enabled: true
Node count: 3
Node IPs: auto-calculated from network
SSH Key: /home/student/.ssh/id_rsa
SSH User: opsadmin
SSH Port: 22
Config file: /home/student/.config/linux-labs/config
```

## SSH access

Two different users connect to the nodes, both from the workstation and both with the settings above:

- root, when `labctl start`, `labctl grade` and `labctl reset` run setup, the grader and the cleanup
- the student, when they follow the solution, which loads the same configuration and runs commands on the nodes

`SSH_KEY_PATH` defaults to `$HOME/.ssh/id_rsa`, and `$HOME` is expanded when the file is read: for root under sudo that is normally `/root/.ssh/id_rsa`, for the student `/home/student/.ssh/id_rsa`. Either install the public key of both users on every node, or point both at one key with an absolute path. Root can read the student's key:

```bash
labctl configure set SSH_KEY_PATH /home/student/.ssh/id_rsa
```

`SSH_USER` (default `opsadmin`) must be able to log in to every node with that key. The labs run their commands on the nodes with `sudo`, so a user other than root needs passwordless sudo there (opsadmin has it in the classroom).

The connections use `BatchMode=yes` and a connect timeout (2 seconds for the reachability test, 10 for commands), with `StrictHostKeyChecking=no`. A missing or wrong key fails at once instead of waiting at a password prompt.

Check every node as the student and as root before class:

```bash
source /opt/linux-labs/lib/load-config.sh
for ip in $(get_all_node_ips); do
  if test_node_connectivity "$ip" >/dev/null; then echo "$ip reachable"; else echo "$ip NOT reachable"; fi
done
```

```bash
sudo bash -c 'source /opt/linux-labs/lib/load-config.sh
for ip in $(get_all_node_ips); do
  if test_node_connectivity "$ip" >/dev/null; then echo "$ip reachable"; else echo "$ip NOT reachable"; fi
done'
```

Both must print `reachable` for every node.

## The clustering labs

- Pacemaker, pcs and the fence agents come from the High Availability repository, which is disabled by default. Its id is `ha` on EL8 and `highavailability` on EL9. RHEL needs the High Availability add-on subscription for it.
- The nodes have no root SSH to each other. The solutions copy files between nodes through the workstation.
- `fence_virsh` in clustering-02 cannot reach a real hypervisor in a normal classroom, so fencing is configured but never fires. The solution sets `migration-threshold=INFINITY` so the failing fence devices do not block the resource.

## When it does not work

`labctl start` stops before it changes anything when the configuration does not fit the lab. lb-01, for example, prints one of:

```
lb-01 needs multi-node labs: run 'sudo labctl configure interactive' and enable them
lb-01 needs 3 nodes, NODE_COUNT is 1: run 'sudo labctl configure set NODE_COUNT 3'
Cannot reach node 1 (172.25.250.10) over SSH as opsadmin
```

The grader reports the same problems as a single FAIL line and stops, for example `Multi-node labs are enabled in the configuration` or `All three nodes are reachable over SSH`.

| Symptom | Check |
|---|---|
| the lab says multi-node labs are off, but you enabled them | `labctl configure list`: the `Config file:` line. A file in `/etc/linux-labs/` hides the user file. |
| wrong addresses in the task | `NODE_IPS` and `NODE_COUNT` in `labctl configure list` |
| `(node 3 not configured)` in the task | `NODE_COUNT` is lower than the lab needs |
| cannot reach a node | the SSH test above, as root and as the student; `SSH_USER` and `SSH_KEY_PATH` |
| packages fail to install on the nodes | the nodes' repositories and internet access; for clustering the High Availability repository |
