# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hands-on Linux sysadmin labs (RHCSA style) for Rocky Linux / RHEL 8 and 9, shipped as one noarch RPM (`linux-labs`). Students run everything through `labctl`. The repo is all Bash: no build system, no test suite, no linter config. Student VMs are the RH classroom layout (network `172.25.250.0/24`), which is where the config defaults come from.

## Layout and how it maps to the installed system

`src/` mirrors the target filesystem. Paths inside it are the paths on the student VM:

- `src/usr/bin/labctl`: the CLI (`start|grade|reset|list|solution|configure`). `start` and `reset` require root; `/etc/sudoers.d/labctl` gives the `student` user passwordless sudo for labctl only.
- `src/opt/linux-labs/lib/`: `colors.sh` (used by single-node graders) and `load-config.sh` (config loader plus multi-node helpers).
- `src/etc/profile.d/labctl.sh`: adds `[LAB:<name>]` to PS1 by reading `/opt/linux-labs/.current_lab`, the state file `labctl start` writes and `labctl reset` removes.
- `labs/<topic>-NN/` installs to `/opt/linux-labs/labs/`.

Every script hardcodes the installed paths (`/opt/linux-labs/...`), so labs cannot be run meaningfully from the checkout on macOS. Test on a Rocky VM after installing the RPM.

## Lab contract

Each lab directory has exactly five files:

| File | Called by | Notes |
|---|---|---|
| `setup.sh` | `labctl start` (as root) | must be executable |
| `grade.sh` | `labctl grade` | exit 0 = pass, 1 = incomplete |
| `cleanup.sh` | `labctl reset` (as root) | must return the VM to a usable state |
| `description.txt` | `labctl list` | `key: value` lines; `list` shows the `objective:` line |
| `solution.md` | `labctl solution` | |

labctl only accepts a lab name if at least one of the three scripts is executable on the installed system. File modes in git are inconsistent (most scripts are `100644`, including tested labs such as `lb-01`), so the installed permissions presumably come from the RPM spec, which is not in the repo (see below).

When adding a lab, also update `LAB_IDEAS.md` (catalog with completion status) and the category list in `README.md`.

## Grading scripts: two styles

**Single-node labs** source `colors.sh`, then redefine `pass`/`fail` locally with counters, and chain checks as `test && pass "..." || { fail "..."; rc=1; }`. Increment counters with `((++passcount))`, never `((passcount++))`: post-increment from 0 returns exit status 1, so in an `&& ... ||` chain a passing check also runs `fail`. This was fixed across the graders in commit 262e8b4; don't reintroduce it. The failure label is `NO PASS`.

**Multi-node labs** (`lb-01..03`, `replication-01..03`, `clustering-01..03`) source `load-config.sh` and call `load_lab_config`. They check `NODES_ENABLED=true` and `NODE_COUNT`, then use `get_node_ip N`, `get_all_node_ips` and `run_on_node IP "cmd"` (SSH with `SSH_USER`/`SSH_KEY_PATH`/`SSH_PORT`). These use `if/else` blocks with `((PASS_COUNT++))`, which is safe there only because the increment is not part of an `&&/||` chain. `load-config.sh` defines its own `pass`/`fail` (label `FAIL`).

The clustering labs are a 3-node Pacemaker/Corosync series (basic cluster, STONITH fencing, quorum and split-brain protection). Use `pcs` and `crm_node` in scripts, not `crm`: crmsh is not installed on the student VMs. Pacemaker, pcs and fence agents come from the `ha` repo, which is disabled by default (`dnf install --enablerepo=ha ...`). Nodes have no root SSH to each other, so solutions copy files between nodes through the workstation. `fence_virsh` in clustering-02 cannot reach a real hypervisor in this environment; the solution sets `migration-threshold=INFINITY` so failing fence devices don't block the resource.

Config precedence in `load_lab_config`: environment variables, then the config file, then defaults. The file is `/etc/linux-labs/config` if it exists, otherwise `~/.config/linux-labs/config`. Node IPs come from `NODE_IPS` (space-separated static list) if set; otherwise node N is `<network base>.<N+9>`. The defaults in `labctl`'s `setup_default_config` and in `load-config.sh` must be kept in sync (they currently disagree on the gateway: `.254` vs `.1`).

## Building the RPM

```bash
scripts/build-rpm-linux.sh   # on a Linux host with rpm-build installed
```

It copies `labs/`, `src/etc`, `src/usr` and `src/opt/linux-labs/lib` into `packaging/rpmbuild/SOURCES/linux-labs-1.0/`, tars it, and runs `rpmbuild`. `packaging/` is gitignored and local only, and the spec file (`packaging/rpmbuild/SPECS/linux-labs.spec`) lives there, not in git. Edit sources in `labs/` and `src/`, never under `packaging/`.

The last two lines of the build script `scp` the RPM to `root@10.0.0.149` and reinstall it there. That is the author's personal test VM; ask before running the script.

## Testing

No automated tests. A lab is verified by installing the RPM on a Rocky VM and running `sudo labctl start X`, doing the solution, `labctl grade X` (should pass), then `sudo labctl reset X`. Commits titled "Tested <lab>." / "Confirmed <lab> works as intended" record which labs went through this. `test_static_ips.sh` is a manual smoke test for the node-IP helpers; it sources the library from `/root/linux-labs/`, so it only runs from a checkout at that path.

## Known issues

- `labs/files-02` uses the Debian user `www-data`; on Rocky it is `apache`, so the lab fails as written.
- `clustering-01..03` are not yet listed in `README.md` or `LAB_IDEAS.md`, and there is no "Tested clustering-NN" commit for them.
- `brainstorm/` holds design notes for future labctl features (class dashboard, break-fix labs, hub/spoke multi-node). They are plans, not implemented behaviour.
