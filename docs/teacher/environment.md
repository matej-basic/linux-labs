# Classroom environment

This page is for teachers who run linux-labs in a course. It lists what a student's machines need and which labs need more than the basics. Multi-node labs have their own page, [multi-node.md](multi-node.md).

Each student needs a workstation and a server, servera. Students run labctl on the workstation, where they have no sudo except for labctl. Every lab that needs root runs on servera: labctl prepares, grades and resets it there over SSH, and the student logs in to servera to do the work. No lab runs on the workstation itself. The multi-node labs use servera, serverb and serverc.

## The workstation

One workstation VM per student, with:

- Rocky Linux, RHEL or AlmaLinux 8 or 9. The installer rejects other distributions and EL10.
- SELinux enforcing, as installed.
- A user named `student`. The package installs `/etc/sudoers.d/labctl` with the rule `student ALL=(ALL) NOPASSWD: /usr/bin/labctl`, so `student` can run labctl as root without a password and nothing else.
- A short host name you recognise. The grade output starts with `Grading <lab> on <host name>` (for a lab on servera: `on servera`), which helps when students send screenshots.

The labs were designed for the Red Hat classroom layout: a workstation at 172.25.250.9 in the network `172.25.250.0/24`, gateway `172.25.250.254`, and the servers servera, serverb and serverc at .10, .11 and .12.

### The servers

servera is needed for every lab; serverb and serverc only for the multi-node labs. Each server needs:

- the same release as the workstation, with bash and coreutils (nothing from linux-labs is installed there; labctl copies what a lab needs)
- SELinux enforcing, as installed; the SELinux labs expect it
- access to the distribution's package repositories, and internet access for the labs that need it (see below). Labs without `internet` in their Needs line may still install a base package such as acl, lvm2, cronie or rsyslog when it is missing
- a user `opsadmin` with full passwordless sudo, for example `/etc/sudoers.d/opsadmin` with `opsadmin ALL=(ALL) NOPASSWD: ALL`
- the workstation's `student` key in `~opsadmin/.ssh/authorized_keys`, so `ssh opsadmin@servera` from the workstation logs in without a password. Create the key on the workstation as student (`ssh-keygen`) and copy it to every server (`ssh-copy-id opsadmin@servera`)

2 GB of RAM per VM, workstation and servers alike, was enough for every lab in the tests.

labctl finds the servers through the lab configuration, not through DNS: servera is node 1, serverb node 2, serverc node 3. On the workstation, `/etc/linux-labs/config` needs at least:

```
NODE_IPS="172.25.250.10 172.25.250.11 172.25.250.12"
SSH_USER="opsadmin"
SSH_KEY_PATH="/home/student/.ssh/id_rsa"
```

`opsadmin` is the default `SSH_USER` and the student's `~/.ssh/id_rsa` the default key, so those two lines only matter when they differ. Without `NODE_IPS`, node N is `<network base>.<N+9>`, which matches the classroom layout. The multi-node labs also need `NODES_ENABLED=true` and `NODE_COUNT`; see [multi-node.md](multi-node.md). `labctl start` and `labctl task` show the student the line `Work on servera: ssh opsadmin@servera`; when the name servera does not resolve to the configured address on the workstation, the line shows the address instead. labctl keeps the servers' host keys in its own `/var/lib/linux-labs/known_hosts` on the workstation and accepts a new server's key on first use.

### A user other than student

The sudoers rule names only `student`. For another account, add a rule for it:

```bash
echo 'labuser ALL=(ALL) NOPASSWD: /usr/bin/labctl' | sudo tee /etc/sudoers.d/labctl-labuser
sudo chmod 0440 /etc/sudoers.d/labctl-labuser
sudo visudo -c
```

The rule must be passwordless. `labctl grade` runs the grader as root by calling `sudo -n` itself, and `-n` never asks for a password. Without such a rule a student sees `Error: grading needs root. Use: sudo labctl grade <lab>`.

## Installing

On every workstation (not on the servers):

```bash
curl -fsSL https://matej-basic.github.io/linux-labs/install | sudo bash
```

The installer writes `/etc/yum.repos.d/linux-labs.repo`, imports the signing key and installs the package, or upgrades it when it is already there. To do the same by hand:

```bash
sudo curl -fsSL -o /etc/yum.repos.d/linux-labs.repo https://matej-basic.github.io/linux-labs/linux-labs.repo
sudo rpm --import https://matej-basic.github.io/linux-labs/RPM-GPG-KEY-linux-labs
sudo dnf install linux-labs
```

New versions arrive with `sudo dnf upgrade linux-labs`, or by running the installer again. Reset active labs (`sudo labctl reset <lab>`) before upgrading from 1.1.0 to 2.0.0: 1.1.0 ran every lab on the workstation. A lab still active after the upgrade cannot be graded; `sudo labctl reset <lab>` with 2.0.0 cleans it up on the workstation and on servera. Each release RPM is also attached to its GitHub Release at https://github.com/matej-basic/linux-labs/releases.

What the package installs:

| Path | Content |
|---|---|
| `/usr/bin/labctl` | the command students use |
| `/opt/linux-labs/labs/` | the labs |
| `/opt/linux-labs/lib/` | grading and configuration libraries |
| `/etc/linux-labs/config.template` | configuration template |
| `/etc/sudoers.d/labctl` | the sudo rule for `student` |
| `/etc/profile.d/labctl.sh` | adds `[LAB:<name>]` to the prompt while a lab is active; labctl also copies it to servera when a lab starts there |
| `/var/lib/linux-labs/` | labctl's `known_hosts` for the servers |
| `/usr/share/doc/linux-labs/` | the student guides |
| `man labctl` | the command reference |

## Checking a classroom

After you set up a classroom, or a template the student VMs are cloned from, run this on a workstation as `student`:

```bash
labctl check
```

It reads the configuration the way `sudo labctl start` does and checks, one line each: which configuration file is in use and the address of each server, the SSH key, the sudoers rule for labctl, the workstation's release, and on every server the SSH login as `SSH_USER` without a password, passwordless sudo and the release. serverb and serverc are checked only when `NODES_ENABLED=true`; `NODE_COUNT` says how many nodes. On servera it also counts the free NICs for the network labs and tries to reach the host of the first enabled package repository. A FAIL line is followed by a line with the fix. WARN lines (multi-node labs off, a server on another major release than the workstation, fewer than two free NICs, no repository access) only affect some labs and do not change the exit status, which is 0 when nothing failed and 1 otherwise.

The command changes nothing on any machine and needs no sudo. Host keys are compared with a temporary copy of labctl's `/var/lib/linux-labs/known_hosts`, so a server whose key changed fails as it would for `labctl start`, with the `ssh-keygen -R` command that fixes it. Each server gets a 5 second connect timeout, so even with three servers down the check ends in about 15 seconds. A healthy classroom with multi-node labs enabled looks like this:

```
Checking the lab environment for student on workstation

Configuration /etc/linux-labs/config is readable .................. PASS
Multi-node labs are enabled for 3 nodes ........................... PASS
servera (node 1) has the address 172.25.250.10 .................... PASS
...
servera has two free NICs for the network labs .................... PASS
servera reaches its package repositories .......................... PASS
...
Overall result .................................................... PASS
19 passed, 0 warnings, 0 failed.
```

## What individual labs need

`labctl list` shows every lab. The catalog at https://github.com/matej-basic/linux-labs/blob/main/docs/catalog.md has a Needs column, and `labctl start` and `labctl task` print a `Needs:` line under the title when a lab needs something:

```
networking-03: Network bonding with failover
Category: Networking    Level: Advanced
Needs: free network interface
========================================================================
```

The values:

| Needs | Meaning | Labs today |
|---|---|---|
| `internet` | setup or the solution installs packages or downloads files | the database, DNS, package and web server labs, the multi-node labs except clustering-03, plus scheduling-03, selinux-02 and selinux-03 |
| `reboot` | the solution reboots the VM to prove a setting persists | storage-01, systemd-04 |
| `free network interface` | a NIC that carries no connection | networking-01, networking-02, networking-03 (two NICs), firewall-02 |
| `N nodes` | the lab runs on N extra machines | lb-*, replication-*, clustering-* |

To list the labs of one course or level:

```bash
labctl list --course aoos
labctl list --level beginner
```

### Free network interfaces

The network labs run on servera. They never touch the interface that carries the default route, which on servera also carries the student's SSH session. They look for an ethernet interface that is not the default-route interface and is not enslaved to a bond or team. If there is none, `labctl start` stops with a message and the lab is not started. networking-03 needs two.

Give each servera two extra NICs on an isolated network without DHCP (in the test environment `ens224` and `ens256` on `Local_NO_DHCP`; `ens192` carries SSH). Extra NICs on the workstation are not used any more and do no harm. NetworkManager creates automatic profiles named `Wired connection 1`, `Wired connection 2` on them; that is fine. Setup turns those profiles off in memory only, without writing anything to disk, and `labctl reset` deletes every profile the lab or the student created and turns the automatic profiles back on. firewall-02 creates its own profile, `fwlab`, on the free NIC.

### Reboots

storage-01 and systemd-04 are checked after a reboot of servera. The student's SSH session closes during the reboot, and the student logs in again when servera is back. The task says so.

### Storage

The storage labs work on loop devices backed by image files, for example `/srv/disk.img` in storage-01. A VM needs no extra disk, only some free space and the `loop` kernel module, which every stock Rocky and RHEL kernel has.

## One lab at a time

A student has one active lab, recorded in `/opt/linux-labs/.current_lab` on the workstation and shown in the prompt as `[LAB:<name>]`. For a lab on servera, servera has the same file and prompt while the lab is active, plus the lab's working copy in `/var/lib/linux-labs/`. Students finish a lab with `sudo labctl reset <lab>` before they start the next one; `labctl start` refuses to start a second lab while one is active. `reset` undoes the setup and the solution: files, users, packages, services, firewall rules, SELinux settings and network profiles.

## Packages

A lab records the package set of its machines when it first starts, and `labctl reset` returns to it. Reset removes every package the lab, its solution or the student installed since then, including dependencies, imported repo keys and added repo files, and it reinstalls a package that setup or the student removed. It also removes the system users and groups those packages created (apache, mysql, named and similar) once they own no files. Packages that were installed before the lab stay, so a server can already run httpd, MySQL or PostgreSQL. The labs that use them work with an existing server and put it back at reset, with its configuration and data.

Reset never downgrades. When an install during the lab upgrades a package that was already there (installing gcc upgrades glibc on Rocky 8.7), the newer version stays.

## Solutions

`labctl solution <lab>` shows the reference solution to anyone on the VM. There is no switch to hide it. If students must not see solutions during an exam, run the exam on VMs where you removed the `solution.md` files, and expect `dnf upgrade` to bring them back.
