# linux-labs documentation

## Students

- [Getting started](student/getting-started.md): install, your first lab from start to reset, reading the grade output, what to do when stuck.
- [Commands](student/commands.md): every labctl command in one table.
- [Troubleshooting](student/troubleshooting.md): labctl error messages and what to do about them.

The student pages are also installed on every lab VM in `/usr/share/doc/linux-labs/`.

## Teachers

- [Classroom environment](teacher/environment.md): what a student VM needs, installing, which labs need internet, a free NIC or a reboot.
- [Multi-node labs](teacher/multi-node.md): nodes, `labctl configure`, `NODE_IPS`, SSH keys, the system and user configuration files.

## Lab authors

- [Lab framework 2.0](author/framework.md): the contract every lab follows.
- [Checking and testing](author/testing.md): `check-labs.sh`, `test-lab.sh`, one lab at a time, known issues.
- [Building and releasing](author/releasing.md): the spec version, tags, CI, signing and the dnf repository on GitHub Pages.

## Labs

- [Lab catalog](catalog.md): every lab with its level, course and needs, generated from the labs.
- [Lab ideas](lab-ideas.md): proposed labs that do not exist yet.
