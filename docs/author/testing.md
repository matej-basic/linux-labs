# Checking and testing labs

A lab is checked twice. `scripts/check-labs.sh` is the static check: it reads the files in the checkout, runs on macOS and Linux, and CI runs it on every push. `scripts/test-lab.sh` is the runtime test: it installs the working tree on a real Rocky VM and plays the lab from start to reset. A lab is done when both pass.

The rules both scripts enforce are in [framework.md](framework.md).

## Static check: scripts/check-labs.sh

```bash
scripts/check-labs.sh                     # all labs plus the repo-level criteria
scripts/check-labs.sh files-04            # selected labs only
scripts/check-labs.sh --strict            # legacy labs fail too
SHELLCHECK=docker scripts/check-labs.sh   # shellcheck from the docker image, as in CI
```

It runs on macOS bash 3.2 and on Linux. For each converted lab it checks:

- the file set, executable bits on disk and in the git index (untracked files: disk only), and shebangs
- `description.txt` keys and values, including `needs:` and its cross-checks against `# solve: reboot` and the `TOPOLOGY` section
- the `task.txt` sections, numbering, placeholders, `GRADING` line, text rules and the no-solving-commands rule
- the `solution.md` headings, step markers, `Verification` line and text rules
- the optional `## Hints` section: before `## Solution`, 2 to 4 numbered hints, no solving commands (the same heuristic as `task.txt`)
- that `grade.sh` uses `grading.sh` and has no legacy helpers, and that `setup.sh` prints no banner
- the optional `known-issues.md`: heading, entry shape (date, releases, status, text), continuation lines, text rules and no solving commands (criterion "known-issues.md follows the format", described in [framework.md](framework.md))
- the `solve.sh` directives and its `solve-lib.sh` line
- `bash -n` and shellcheck on all four scripts

A run without lab names also checks two repo-level criteria. The repo root may hold only `README.md`, `CHANGELOG`, `LICENSE`, `CLAUDE.md`, `.github/`, `.gitignore`, `.claude/` and the directories `labs/`, `src/`, `rpm/`, `scripts/`, `pages/` and `docs/` (tracked files and untracked files that are not ignored both count). And `docs/catalog.md` must match what `scripts/gen-catalog.sh` generates now; if it does not, the check says "run scripts/gen-catalog.sh".

Each failing criterion lists up to ten problem lines under it. The exit status is 0 when everything passes, 1 on any failure and 2 on a usage error. CI runs it in the job `check`, and the RPM build depends on that job.

All 55 labs are converted, so `--strict` and a normal run give the same result today. `--strict` stays useful as the gate for anything new: a lab without `task.txt` is reported as LEGACY and fails only under `--strict`.

### shellcheck

shellcheck comes from PATH, else from docker (`koalaman/shellcheck:stable`), else it is skipped with a note. `SHELLCHECK=none` skips it on purpose and `SHELLCHECK=docker` forces the docker image. CI pulls the same image and sets `SHELLCHECK=docker`, so a local run with that setting reports exactly what CI reports.

It runs at the default severity with one allowed exclusion, `SC1091` (not following `/opt/linux-labs/...` and `solve-lib.sh` sources). Anything else is fixed, or silenced on the specific line with `# shellcheck disable=SCxxxx # <reason>` when the warning is wrong for that line.

### False positives: scripts/check-labs.allow

The criterion "task.txt states the end state, no solving commands" is a pattern check and sometimes flags prose, for example a continuation line that happens to start with "cat". Such a line goes into `scripts/check-labs.allow`: a `# <reason>` comment line, then `<lab>: <the line without its leading spaces>` directly below it.

```
# Prose, not a command: the continuation line starts with "cat"
files-09: cat and dog names are listed in /srv/pets.txt.
```

An entry without the reason line fails the check. Use the file only for false positives; a line that really shows a solving command is rewritten.

## Runtime test: scripts/test-lab.sh

```bash
scripts/test-lab.sh 10.0.0.188 files-04            # one lab
scripts/test-lab.sh 10.0.0.188 files-04 users-01   # several, strictly one after the other
```

It runs from the Mac against a host that has the `linux-labs` RPM installed, a `student` user and root SSH access with a key (BatchMode). It copies the working tree's `labctl`, `lib/*.sh` and the lab directories (without `solve.sh`) over the installed RPM files, plus the man page and the profile script when they differ, and runs `restorecon` on them. Then, per lab:

| Step | Expected exit |
|---|---|
| `sudo labctl start <lab>` as student (header and task printed) | 0 |
| `labctl task <lab>` as student | 0 |
| `labctl grade <lab>` as student | 1 |
| `solve.sh` as root from a temporary directory | 0 |
| reboot, wait for SSH, a new boot id and the end of the boot (only with `# solve: reboot`) | |
| `labctl grade <lab>` as student and as root | 0 |
| `sudo labctl reset <lab>` as student | 0 |
| `labctl grade <lab>` as student | 1 |

After the reset the paths and packages declared in `solve.sh`, the state file `/opt/linux-labs/state/<lab>` and `/opt/linux-labs/.current_lab` must be gone.

The output is one criterion block per lab and a summary. The full log, with every command, its output and its exit status, goes to `packaging/test-logs/<timestamp>-<host>.log`.

- Exit status: 0 all labs passed, 1 a lab failed or the run aborted, 2 nothing failed but at least one lab was skipped, 3 usage error. Exit 2 is not a pass.
- A legacy lab (no `task.txt` or no `solve.sh`) is skipped with a message, not failed.
- The run aborts before touching the host if a lab is active there, and stops if a lab is still active after its reset. Do not reset a lab someone else started; report it and wait.
- It deletes nothing on the host except through the lab's own `cleanup.sh` and its own temporary directory. Afterwards `rpm -V linux-labs` lists the replaced files, and `dnf reinstall linux-labs` restores the packaged versions.
- Runtime tests do not run in CI: most labs need systemd, firewalld or SELinux. Results go into the release notes (for example "Verified on Rocky 8.7 workstation: N of 55 PASS"), not into commits or files in git.

### One lab at a time

labctl keeps a single active lab in `/opt/linux-labs/.current_lab`, and the `[LAB:...]` prompt reads it. Two runs against the same host overwrite each other's state, so labs are tested strictly one at a time:

- never two `test-lab.sh` runs against the same host, in parallel or from two sessions
- never a test while a person is working through a lab on that host
- build and test one new lab before starting the next

### The test workstation

| Item | Value |
|---|---|
| Host | `10.0.0.188`, Rocky 8.7, SELinux enforcing |
| Package | `linux-labs` RPM installed |
| Users | `student`; root SSH access with a key from the Mac |
| Default route | `ens192`, never touched by a lab |
| Free NICs | `ens224` and `ens256`, on an isolated network for network labs |
| Nodes | servera, serverb and serverc (10.0.0.189 to .191) |

SSH key access to servera, serverb and serverc has been failing, so the multi-node labs (`lb-*`, `replication-*`, `clustering-*`) cannot be runtime-tested yet. Check SSH to the nodes before promising a multi-node test; if it fails, stop at the static check and say so.

### Snapshots of the lab VMs

Before a test run that can break a VM (network, storage, firewall, reboot labs), snapshot the four lab VMs: `scripts/lab-vms.sh snapshot <name>`.
If a lab leaves a VM unreachable, `scripts/lab-vms.sh revert <name> --yes` puts all four back; a single wedged guest takes `scripts/lab-vms.sh power-cycle <vm> --yes`.
`scripts/lab-vms.sh status` shows power state and the existing snapshots.
The script needs `.config/vcenter_creds` and govc, and only ever touches workstation, servera, serverb and serverc.

## Known issues

A bug in the lab is fixed, never recorded. If `setup.sh` misses a leftover, a criterion is wrong on Rocky 9 or `cleanup.sh` fails on a half-done lab, change the lab and run both tests again.

A known issue is only what the lab cannot fix itself:

- upstream: package versions, mirrors that are slow or out of sync
- release differences between Rocky 8 and 9, such as policy defaults or packages missing from a minimal install
- the environment: no carrier on a NIC, nodes that cannot be reached
- a deliberate limitation, for example `fence_virsh` in clustering-02, which cannot reach a real hypervisor in the classroom

Each one becomes an entry in `labs/<id>/known-issues.md`, in the format described in [framework.md](framework.md) ("known-issues.md"). Use status `workaround` when the lab already works around the problem, `open` when a student can still hit it and `fixed` when the cause is gone; keep fixed entries as history.

`scripts/check-labs.sh` validates the file, the catalog shows the count of `open` and `workaround` entries with a link to it, and the RPM never contains it.

Entries are written by the runtime test agents and by hand, after a runtime test has shown the problem. A static review does not write entries. Issues reported by the agents that converted the labs to 2.0 are not pre-filled: each runtime test confirms or drops them.

The `check-labs.sh` validation of the file and the catalog column are planned, not yet implemented. Until then `check-labs.sh` rejects the extra file (see framework.md), so the first entry lands together with that change.
