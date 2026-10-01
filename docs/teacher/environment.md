# Classroom environment

This page is for teachers who run linux-labs in a course. It lists what a student VM needs and which labs need more than the basics. Multi-node labs have their own page, [multi-node.md](multi-node.md).

## The student VM

One VM per student, with:

- Rocky Linux, RHEL or AlmaLinux 8 or 9. The installer rejects other distributions and EL10.
- SELinux enforcing, as installed. The SELinux labs expect it.
- A user named `student`. The package installs `/etc/sudoers.d/labctl` with the rule `student ALL=(ALL) NOPASSWD: /usr/bin/labctl`, so `student` can run labctl as root without a password and nothing else.
- Internet access for the many labs that install packages (see below).
- A short host name you recognise. The grade output starts with `Grading <lab> on <host name>`, which helps when students send screenshots.

The labs were designed for the Red Hat classroom layout: a workstation at 172.25.250.9 in the network `172.25.250.0/24`, gateway `172.25.250.254`, and the servers servera, serverb and serverc at .10, .11 and .12. Single-node labs run on any VM that meets the list above.

### A user other than student

The sudoers rule names only `student`. For another account, add a rule for it:

```bash
echo 'labuser ALL=(ALL) NOPASSWD: /usr/bin/labctl' | sudo tee /etc/sudoers.d/labctl-labuser
sudo chmod 0440 /etc/sudoers.d/labctl-labuser
sudo visudo -c
```

The rule must be passwordless. `labctl grade` runs the grader as root by calling `sudo -n` itself, and `-n` never asks for a password. Without such a rule a student sees `Error: grading needs root. Use: sudo labctl grade <lab>`.

## Installing

On every student VM:

```bash
curl -fsSL https://matej-basic.github.io/linux-labs/install | sudo bash
```

The installer writes `/etc/yum.repos.d/linux-labs.repo`, imports the signing key and installs the package, or upgrades it when it is already there. To do the same by hand:

```bash
sudo curl -fsSL -o /etc/yum.repos.d/linux-labs.repo https://matej-basic.github.io/linux-labs/linux-labs.repo
sudo rpm --import https://matej-basic.github.io/linux-labs/RPM-GPG-KEY-linux-labs
sudo dnf install linux-labs
```

New versions arrive with `sudo dnf upgrade linux-labs`, or by running the installer again. Each release RPM is also attached to its GitHub Release at https://github.com/matej-basic/linux-labs/releases.

What the package installs:

| Path | Content |
|---|---|
| `/usr/bin/labctl` | the command students use |
| `/opt/linux-labs/labs/` | the labs |
| `/opt/linux-labs/lib/` | grading and configuration libraries |
| `/etc/linux-labs/config.template` | configuration template |
| `/etc/sudoers.d/labctl` | the sudo rule for `student` |
| `/etc/profile.d/labctl.sh` | adds `[LAB:<name>]` to the prompt while a lab is active |
| `/usr/share/doc/linux-labs/` | the student guides |
| `man labctl` | the command reference |

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
| `internet` | setup or the solution installs packages or downloads files | the database, DNS, package, web server and multi-node labs, plus scheduling-03, selinux-02 and selinux-03 |
| `reboot` | the solution reboots the VM to prove a setting persists | storage-01, systemd-04 |
| `free network interface` | a NIC that carries no connection | networking-01, networking-02, networking-03 (two NICs), firewall-02 |
| `N nodes` | the lab runs on N extra machines | lb-*, replication-*, clustering-* |

To list the labs of one course or level:

```bash
labctl list --course aoos
labctl list --level beginner
```

### Free network interfaces

The network labs never touch the interface that carries the default route. They look for an ethernet interface that is not the default-route interface and is not enslaved to a bond or team. If there is none, `labctl start` stops with a message and the lab is not started. networking-03 needs two.

Give each student VM one or two extra NICs on an isolated network. NetworkManager creates automatic profiles named `Wired connection 1`, `Wired connection 2` on them; that is fine. Setup removes or deactivates those profiles on the interfaces the lab uses, and `labctl reset` deletes every profile the lab created.

### Reboots

storage-01 and systemd-04 are checked after a reboot. Students reboot their own VM, so they need a console (or SSH that comes back) and enough time in the session.

### Storage

The storage labs work on loop devices backed by image files, for example `/srv/disk.img` in storage-01. A VM needs no extra disk, only some free space and the `loop` kernel module, which every stock Rocky and RHEL kernel has.

## One lab at a time

A VM has one active lab, recorded in `/opt/linux-labs/.current_lab` and shown in the prompt as `[LAB:<name>]`. Students finish a lab with `sudo labctl reset <lab>` before they start the next one. `reset` undoes the setup and the solution: files, users, packages, services, firewall rules, SELinux settings and network profiles.

## Solutions

`labctl solution <lab>` shows the reference solution to anyone on the VM. There is no switch to hide it. If students must not see solutions during an exam, run the exam on VMs where you removed the `solution.md` files, and expect `dnf upgrade` to bring them back.
