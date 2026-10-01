# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hands-on Linux sysadmin labs (RHCSA style) for Rocky Linux / RHEL 8 and 9, shipped as one noarch RPM (`linux-labs`). Students run everything through `labctl`. The repo is all Bash: no build system and no unit tests. `scripts/check-labs.sh` is the static check (runs in CI) and `scripts/test-lab.sh` is the runtime test on a real VM (run by hand). Student VMs are the RH classroom layout (network `172.25.250.0/24`), which is where the config defaults come from.

The labs are being migrated to lab framework 2.0 (this file describes it). A lab with a `task.txt` is converted; a lab without one is legacy and keeps working through the fallbacks described below until it is converted. `files-04` is the reference lab: when in doubt, copy its structure.

## Layout and how it maps to the installed system

`src/` mirrors the target filesystem. Paths inside it are the paths on the student VM:

- `src/usr/bin/labctl`: the CLI (`start|task|grade|reset|list|solution|configure`). `start` and `reset` require root; `/etc/sudoers.d/labctl` gives the `student` user passwordless sudo for labctl only.
- `src/opt/linux-labs/lib/`: `grading.sh` (grading library for all 2.0 graders), `load-config.sh` (config loader plus multi-node helpers) and `colors.sh` (used only by legacy graders; delete it once no lab uses it).
- `src/etc/profile.d/labctl.sh`: adds `[LAB:<name>]` to PS1 by reading `/opt/linux-labs/.current_lab`, the state file `labctl start` writes and `labctl reset` removes.
- `src/usr/share/man/man1/labctl.1`: the man page. Update it when labctl commands change.
- `labs/<topic>-NN/` installs to `/opt/linux-labs/labs/` (without `solve.sh`).
- `scripts/`: `build-rpm-linux.sh`, `check-labs.sh` (with its allowlist `check-labs.allow`), `test-lab.sh`, `solve-lib.sh` (helpers for `solve.sh`), and the release helpers `sign-rpm.sh` and `update-pages.sh`. None of these are shipped.

Every lab script hardcodes the installed paths (`/opt/linux-labs/...`), so labs cannot be run from the checkout on macOS. Test on a Rocky VM with `scripts/test-lab.sh`.

## Lab contract (framework 2.0)

A converted lab directory has exactly these seven files and nothing else:

| File | Shipped | Called by | Purpose |
|---|---|---|---|
| `setup.sh` | yes | `labctl start` (as root) | prepares the system, prints nothing |
| `grade.sh` | yes | `labctl grade` (as student or root) | checks the final state with `lib/grading.sh` |
| `cleanup.sh` | yes | `labctl reset` (as root) | undoes setup and solution |
| `description.txt` | yes | `labctl list`, task header | metadata |
| `task.txt` | yes | `labctl start`, `labctl task` | the task text shown to the student |
| `solution.md` | yes | `labctl solution` | reference solution for students |
| `solve.sh` | no | `scripts/test-lab.sh` (as root) | automatic solver, same steps as `solution.md` |

`setup.sh`, `grade.sh`, `cleanup.sh` and `solve.sh` start with `#!/bin/bash` and are executable on disk and in git (mode `100755`; `git update-index --chmod=+x` if needed). labctl only accepts a lab name if at least one of the three shipped scripts is executable on the installed system; the spec's `%install` also runs `chmod 0755` on every `*.sh`. All shipped text files are plain ASCII.

When adding a lab, also update `LAB_IDEAS.md` (catalog with completion status) and the category list in `README.md`.

### description.txt

One `key: value` line per key (exactly one space after the colon), no blank lines, no comments, no other keys. Recommended order:

```
title: Brace expansion and file organisation
category: Files
complexity: Beginner
objective: Create many files with brace expansion and sort them into a directory tree by name.
course: aoos
course_lab: 01
```

- `title` (required): sentence case, at most 60 characters, no final period. Shown in the task header and as the `solution.md` heading.
- `category` (required): one of `Database Replication`, `Databases`, `DNS`, `Files`, `Firewall`, `High Availability Clustering`, `Load Balancing`, `Logging`, `Networking`, `Packages`, `Scheduling`, `SELinux`, `Storage`, `Systemd`, `Users`, `Web Servers`. A new category needs the `CATEGORIES` list in `check-labs.sh` updated.
- `complexity` (required): `Beginner`, `Intermediate` or `Advanced`. Shown as `Level:` in the header.
- `objective` (required): one sentence, shown by `labctl list`.
- `course` and `course_lab` (optional, together): course code and two-digit lab number.

The legacy keys `estimated_time`, `requirements` and `skills` are retired. Move anything a student needs to know into `task.txt` (PREREQUISITES or NOTES).

### task.txt

`labctl start` (after `setup.sh` succeeds) and `labctl task` print a header, then `task.txt` with placeholders filled in:

```
files-04: Brace expansion and file organisation
Category: Files    Level: Beginner
========================================================================

OBJECTIVE
  ...
```

Format rules (all enforced by `check-labs.sh`):

- Sections, in this order, each heading on its own line in column 0, exactly as written:

  | Heading | Required |
  |---|---|
  | `OBJECTIVE` | yes, and it is the first line of the file |
  | `TOPOLOGY` | multi-node labs only (required there, forbidden in single-node labs) |
  | `PREREQUISITES` | optional |
  | `TASKS` | yes |
  | `EXPECTED RESULT` | optional |
  | `PRACTICE (not graded)` | optional |
  | `NOTES` | yes |
  | `GRADING` | yes |

- Every other non-blank line is body text indented by at least two spaces. A heading is followed directly by its first body line, and exactly one blank line separates sections. No blank lines at the start or end, never two blank lines in a row, and the file ends with a newline.
- `TASKS` items are numbered `  1. `, `  2. `, ... from 1 without gaps, at a two-space indent. Continuation lines and sub-lists are indented to the item text (five spaces); command examples and drawings are indented by seven spaces with a blank line before and after.
- `GRADING` contains the line `  labctl grade <id>` (no `sudo`: graders work as the student).
- Lines are at most 72 columns, measured on the raw file before placeholders are filled in. Lines that contain a URL (`http://` or `https://`) are exempt.
- Plain printable ASCII only: no tabs, no trailing spaces, no emoji, no box drawing (use `tree --charset=ascii` style `|--` and `` `-- ``), no arrows such as `->` or `=>` outside commands (use words).
- Tone: neutral and imperative ("Create", "Configure"), one fact per sentence, no exclamation marks, no capitals for emphasis ("not as root", never "NOT as root"), no hints that give away the solution. Name the things the grader checks; do not describe how the grader works.
- Describe the end state, never how to reach it (see the next subsection).
- `TASKS` describes exactly what `grade.sh` checks, no more and no less. Practice items that are not graded go to `PRACTICE (not graded)`. `EXPECTED RESULT` describes the final state in prose when it helps.

#### Describe the end state, never the solution

The task screen (`task.txt`, and anything `setup.sh` prints) says WHAT the required end state is, never HOW to reach it. It must not contain the commands, options, command syntax, globs or brace patterns that solve a graded task or are a step toward it.

- Allowed: the target state (paths, names, owners, permissions, counts, values, the expected tree), the input data the student must use (URLs to download, file names, user names, IP addresses, values), and references to man pages by name in `NOTES` (for example `man bash (section Brace Expansion)`), without command lines or options.
- A command may appear only when it is neither part of what is graded nor a step toward it. `labctl grade <id>` in `GRADING` is the standard case; a key sequence to leave an editor is another.
- A requirement about the method that is not graded (for example "use brace expansion") is stated in words, marked with "should", and says that it is not graded.
- `solution.md` is the only place for commands.

Bad (gives the solution away):

```
  2. In /srv/archive, run exactly this command. It creates 108 files:

       touch {report,memo,chart}_{sep,oct,nov,dec}_{a,b,c}{1,2,3}
```

Good (describes the result and the input data):

```
  2. Create 108 empty files in /srv/archive. Each file name has the
     form <type>_<month>_<letter><digit>, for example chart_dec_b2:

       type     report, memo or chart
       month    sep, oct, nov or dec
```

The per-lab review agents apply this rule to every lab: rewrite task text that shows solving commands, options, globs or brace patterns, and move the commands into `solution.md`.

`check-labs.sh` enforces it as far as a pattern check can (criterion `task.txt states the end state, no solving commands`). It flags a body line when, after its indent and an optional `- ` or `N. ` marker, the line starts with a prompt (`$ ` or `# `), or its first word is one of the commands in `TASK_COMMANDS` in `check-labs.sh` (`touch`, `mkdir`, `mv`, `cp`, `rm`, `chmod`, `chown`, `useradd`, `dnf`, `rpm`, `systemctl`, `firewall-cmd`, `nmcli`, `semanage`, `restorecon`, `setsebool`, `mount`, `mkfs*`, `lvcreate`, `tar`, `curl`, `crontab`, `sed`, `echo`, `cat`, `find`, `sudo` and others) followed by an argument (for `find` and `mount` only when the argument starts with `-`, `/`, `.`, `~` or `$`, so that prose such as "find out" passes). It also flags any brace pattern such as `{a,b}` and any glob such as `report_*`. Commands in the middle of a sentence are not detected; reviewers catch those. For a false positive, add an entry to `scripts/check-labs.allow`: a `# <reason>` comment line, then `<lab>: <the line without its leading spaces>` directly below it. An entry without the reason line fails.

Placeholders are the only dynamic content. The full list (keep `render_task` in labctl and `PLACEHOLDERS` in `check-labs.sh` in sync):

| Placeholder | Value |
|---|---|
| `{{EL_MAJOR}}` | major release from `/etc/os-release`, e.g. `8` |
| `{{ARCH}}` | `uname -m`, e.g. `x86_64` |
| `{{HOSTNAME}}` | `uname -n` |
| `{{LAB_USER}}` | `SUDO_USER` if set and not root, else the current user if not root, else `student` |
| `{{NODE_COUNT}}` | `NODE_COUNT` from `load-config.sh` |
| `{{NODE1_IP}}` .. `{{NODE9_IP}}` | `get_node_ip N` from `load-config.sh`; `(node N not configured)` when N > `NODE_COUNT` |

Any other `{{...}}` fails `check-labs.sh`; at runtime labctl prints it unchanged and warns on stderr. Values the lab computes at setup time (random names, ports) are not placeholders: write the task so it does not need them, or have setup put them in a file the task points to.

### setup.sh

- Runs as root from `labctl start`. On success it prints nothing at all: no banner, no progress, no `clear`. labctl prints the task.
- On failure it prints a clear message to stderr and exits non-zero. labctl then reports the failure, does not write `.current_lab` and does not print the task.
- Idempotent: running it twice, or after a partial solution, gives the same starting state. Start by removing what a previous run or the solution left behind.
- Use `set -eu` (not `pipefail` with pipelines that end early, such as `getent passwd | awk '... exit'`).
- Per-lab state (owner name, start transaction id, generated values) goes in the file `/opt/linux-labs/state/<lab>` (or a directory of that name), mode `0644` so the grader can read it as the student. `cleanup.sh` removes it.
- The lab user is `${SUDO_USER:-student}`, falling back to the first regular user if that account does not exist (see `files-04`). Record it in the state file if the grader needs it.

### cleanup.sh

- Runs as root from `labctl reset`. Undoes everything `setup.sh` did and everything `solve.sh` or a student following `solution.md` creates: files, users, packages, services, firewall rules, SELinux settings, the state file. It must leave the VM usable for the next lab and must not fail when the lab was never started or only half done (use `|| true` and `rm -f` where needed).
- It may print short progress lines but should normally print nothing. Exit 0 on success; for a converted lab a non-zero exit makes `labctl reset` report the failure (`.current_lab` is removed either way).

### Network labs

- Never touch the interface that carries the default route (`ip route show default`), or its connection profile. The workstation has free NICs (`ens224`, `ens256`) on an isolated network for these labs.
- `setup.sh` detects free interfaces (ethernet, not the default-route interface, not enslaved) and refuses to start with a clear stderr message if there are not enough. The detected name goes into the state file; `task.txt` refers to "the first free interface" or tells the student how to find the name, since it is not a placeholder.
- NetworkManager creates automatic profiles named `Wired connection 1`, `Wired connection 2`, ... on free NICs. `setup.sh` deletes or deactivates the auto profiles on the interfaces the lab uses, and `cleanup.sh` deletes every profile the lab or the solution created and leaves those interfaces unmanaged by any lab profile (NetworkManager may recreate its auto profile; that is fine).

## Grading scripts

All converted graders use `lib/grading.sh`. Single-node and multi-node graders follow the same rules; there are no local `pass`/`fail` helpers any more.

Output (Red Hat style, 72 columns, labels exactly `PASS` and `FAIL`, colour only on the result word and only when stdout is a terminal and `NO_COLOR` is empty):

```
Grading files-04 on workstation

Directory /srv/archive exists ..................................... PASS
All 12 <type>/<month> directories exist ........................... FAIL

Overall result .................................................... FAIL
1 of 2 criteria met.
```

API:

| Function | Meaning |
|---|---|
| `grade_begin <lab>` | reset counters, print `Grading <lab> on <short hostname>` and a blank line |
| `criterion "<text>" <cmd> [args...]` | run the command with stdin, stdout and stderr on `/dev/null`; PASS if it exits 0 |
| `criterion_result "<text>" <rc>` | record a result computed in shell: `0` is PASS, anything else FAIL |
| `grade_require_state <lab> [<file>]` | if the state file (default `/opt/linux-labs/state/<lab>`) is not readable, record the single FAIL criterion `Lab was started with labctl start` and end grading |
| `grade_abort "<text>"` | record `<text>` as FAIL and end grading (for preconditions such as the multi-node configuration) |
| `grade_end` | print the blank line, `Overall result` and `N of M criteria met.`, then exit 0 if every criterion passed, else 1 (also 1 if there were no criteria) |

`grade_reset`, `grade_summary` (summary without exit) and `grade_line "<text>" <label>` (one formatted line, nothing counted) exist for the repo tools; graders do not need them.

Rules:

- `source /opt/linux-labs/lib/grading.sh` on its own line, `grade_begin <id>` and `grade_end` each on their own line. Do not source `colors.sh`, do not define or call `pass`/`fail`/`ok`/`err`, do not use `NO PASS` and do not use `set -e` (failed checks are expected). `set -u` is fine; the library is safe under it.
- Criterion text is the desired state, as a short statement: `Directory /srv/archive exists`, `httpd is enabled and running`, `Port 8080/tcp is open in the firewall`. Not a question, not "Checking ...", not a hint. Keep it at most 64 characters; longer text wraps at word boundaries with a two-space continuation indent, which works but looks worse.
- No other output: no hints, no counts in the text ("3 of 12 missing"), no examples of what is wrong, no debug lines. `solution.md` covers help. Dynamic values that define the target (the owner name, a node IP) may appear in the text.
- Checks that need more than one command go into a shell function defined in `grade.sh` and passed to `criterion`. `criterion` and `criterion_result` always return 0, so the grader always runs to the end; never use `((count++))`-style counters (the library uses `$((n + 1))`).
- If the lab has a state file, call `grade_require_state` right after `grade_begin`. Grading must work as the student and as root and give the same result.
- Multi-node graders still source `load-config.sh` for `get_node_ip` and `run_on_node`, but use `grading.sh` for all output. Typical preconditions: `[ "$NODES_ENABLED" = true ] || grade_abort "Multi-node labs are enabled in the configuration"`.

Example (`labs/files-04/grade.sh`, shortened):

```bash
#!/bin/bash
# files-04 grader
source /opt/linux-labs/lib/grading.sh

ROOT=/srv/archive
STATE_FILE=/opt/linux-labs/state/files-04

grade_begin files-04
grade_require_state files-04 "$STATE_FILE"
owner=$(head -n 1 "$STATE_FILE")

month_dirs_exist() {
	local t m
	for t in report memo chart; do
		for m in sep oct nov dec; do
			[ -d "$ROOT/$t/$m" ] || return 1
		done
	done
}

criterion "Directory $ROOT exists" test -d "$ROOT"
criterion "All 12 <type>/<month> directories exist" month_dirs_exist

# A result computed in shell
rc=1
[ "$(stat -c %U "$ROOT" 2>/dev/null)" = "$owner" ] && rc=0
criterion_result "Directory $ROOT is owned by $owner" "$rc"
grade_end
```

### Legacy graders (until every lab is converted)

Legacy single-node graders source `colors.sh`, redefine `pass`/`fail` with counters and chain `test && pass "..." || { fail "..."; rc=1; }`, label `NO PASS`. They must use `((++passcount))`, never `((passcount++))`: post-increment from 0 returns status 1, so in an `&& ... ||` chain a passing check also runs `fail` (fixed in commit 262e8b4). Legacy multi-node graders use `pass`/`fail` from `load-config.sh` (label `FAIL`) with `((PASS_COUNT++))` inside `if/else`. Both styles go away with the conversion; `pass`/`fail` in `load-config.sh` stay until the last multi-node lab is converted.

## Multi-node labs

`lb-01..03`, `replication-01..03` and `clustering-01..03` source `load-config.sh` and call `load_lab_config`. They check `NODES_ENABLED=true` and `NODE_COUNT`, then use `get_node_ip N`, `get_all_node_ips` and `run_on_node IP "cmd"` (SSH with `SSH_USER`/`SSH_KEY_PATH`/`SSH_PORT`). Their `task.txt` has a `TOPOLOGY` section with an ASCII drawing and uses `{{NODEn_IP}}` for addresses.

The clustering labs are a 3-node Pacemaker/Corosync series (basic cluster, STONITH fencing, quorum and split-brain protection). Use `pcs` and `crm_node` in scripts, not `crm`: crmsh is not installed on the student VMs. Pacemaker, pcs and fence agents come from the `ha` repo, which is disabled by default (`dnf install --enablerepo=ha ...`). Nodes have no root SSH to each other, so solutions copy files between nodes through the workstation. `fence_virsh` in clustering-02 cannot reach a real hypervisor in this environment; the solution sets `migration-threshold=INFINITY` so failing fence devices don't block the resource.

Config precedence in `load_lab_config`: environment variables, then the config file, then defaults. The file is `/etc/linux-labs/config` if it exists, otherwise `~/.config/linux-labs/config`. Node IPs come from `NODE_IPS` (space-separated static list) if set; otherwise node N is `<network base>.<N+9>`. Defaults (network `172.25.250.0/24`, gateway `.254`, the RH classroom bastion) are duplicated in `labctl`, `load-config.sh`, `config.template` and the docs (README, QUICKSTART, CONFIGURE_SYSTEM); change them everywhere together.

## solution.md

Same ASCII, width (72 columns, URL lines exempt), whitespace and tone rules as `task.txt`. Structure:

````
# files-04: Brace expansion and file organisation

## Solution

1. [user] Change to the lab directory and create the 108 files with
   brace expansion:

   ```bash
   cd /srv/archive
   touch {report,memo,chart}_{sep,oct,nov,dec}_{a,b,c}{1,2,3}
   ```

2. [sudo] Install the package:

   ```bash
   sudo dnf -y install joe
   ```

## Verification

```bash
labctl grade files-04
```

## Explanation

Short prose: why the steps work, and the pitfalls the grader catches.
````

- Line 1 is `# <id>: <title>` with the title from `description.txt`. The only `##` headings are `Solution`, `Verification`, `Explanation`, in that order. `###` subheadings inside `Solution` are allowed (for example one per node).
- Steps are numbered `1.`, `2.`, ... in column 0, without gaps, and each starts with `[user]` (run as the normal lab user, no sudo) or `[sudo]` (needs root; the commands carry `sudo`). Code blocks are indented three spaces under their step.
- `## Verification` runs `labctl grade <id>`; other read-only commands may come before it.
- `## Explanation` is short prose, no step list.

## solve.sh

The automatic solver, used only by `scripts/test-lab.sh`. It is in git but never shipped: `build-rpm-linux.sh` drops it from the source tarball and the spec deletes any `solve.sh` under the buildroot.

```bash
#!/bin/bash
# Reference solution for files-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/archive
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 3 [user]
run_as_student <<'STEPS'
cd /srv/archive
touch {report,memo,chart}_{sep,oct,nov,dec}_{a,b,c}{1,2,3}
STEPS
```

- It performs the same steps as `solution.md`, in the same order, and the comments name the step numbers. `[user]` steps go through `run_as_student`; `[sudo]` steps run directly (the script is root).
- `run_as_student` (from `scripts/solve-lib.sh`) runs its argument, or its standard input when there is no argument, as `student` in a login shell (`runuser -l`, working directory `~student`) with `bash -euo pipefail`. Code passed on stdin must not read stdin itself.
- It runs as root from a temporary directory on the host, after `sudo labctl start <lab>`, so it can rely on the state `setup.sh` created. It must exit 0 on success and non-zero on any failure (`set -euo pipefail`).
- Safe to re-run: after `labctl reset` and `labctl start` it must work again, so it does not depend on anything left over from an earlier run.
- It declares, in comment lines `# solve: <directive>`, what the runtime test needs to know. At least one directive is required:
  - `# solve: path <absolute path>`: a path the lab or its solution creates; it must be gone after `labctl reset`. One line per path.
  - `# solve: package <name>`: a package the solution installs; it must not be installed after `labctl reset`.
  - `# solve: reboot`: the lab needs a reboot after solving (for example to prove that a setting persists); `test-lab.sh` reboots the host, waits for SSH, a new `/proc/sys/kernel/random/boot_id` and the end of the boot, and grades afterwards.
  - `# solve: none`: nothing to declare (only allowed on its own).
- `/opt/linux-labs/state/<lab>` and `/opt/linux-labs/.current_lab` are always checked; do not declare them.

## Checking and testing

### Static check: scripts/check-labs.sh

```bash
scripts/check-labs.sh                 # all labs; legacy labs reported, not failed
scripts/check-labs.sh files-04        # selected labs
scripts/check-labs.sh --strict        # legacy labs fail too (end state of the migration)
```

Runs on macOS bash 3.2 and on Linux. For each converted lab it checks the file set, executable bits on disk and in the git index (untracked files: disk only), shebangs, `description.txt` keys and values, the `task.txt` sections, numbering, placeholders, `GRADING` line, text rules and the no-solving-commands rule, the `solution.md` headings, step markers, `Verification` line and text rules, that `grade.sh` uses `grading.sh` and has no legacy helpers, that `setup.sh` has no banner, the `solve.sh` directives and `solve-lib.sh` line, `bash -n`, and shellcheck. Each failing criterion lists up to ten problem lines under it. Exit 1 on any failure. CI runs it on every push and PR (job `check`, which the RPM build depends on).

shellcheck comes from PATH, else from docker (`koalaman/shellcheck:stable`), else it is skipped with a note (`SHELLCHECK=none` skips it on purpose). It runs at the default severity with one allowed exclusion, `SC1091` (not following `/opt/linux-labs/...` and `solve-lib.sh` sources). Anything else is fixed, or silenced on the specific line with `# shellcheck disable=SCxxxx # <reason>` when the warning is wrong for that line.

### Runtime test: scripts/test-lab.sh

```bash
scripts/test-lab.sh 10.0.0.188 files-04            # one lab
scripts/test-lab.sh 10.0.0.188 files-04 users-01   # several, strictly one after the other
```

Run from the Mac against the workstation (10.0.0.188, Rocky 8.7, SELinux enforcing, `linux-labs` RPM installed, user `student`, root SSH key access). It copies the working tree's `labctl`, `lib/*.sh` and the lab directories (without `solve.sh`) over the installed RPM files, plus the man page and profile script when they differ, and runs `restorecon`. Then per lab: `sudo labctl start` as student (expect 0, header and task printed), `labctl task` (0), grade as student (1), `solve.sh` as root from a temporary directory (0), optional reboot, grade as student and as root (0), `sudo labctl reset` as student (0), grade (1), declared paths and packages gone, state file gone, no lab active. Output is one criterion block per lab and a summary; the full log (commands, outputs, exit codes) goes to `packaging/test-logs/<timestamp>-<host>.log`.

- Legacy labs (no `task.txt` or no `solve.sh`) are skipped with a message, not failed. Exit status: 0 all passed, 1 a failure or an abort, 2 nothing failed but something was skipped.
- The run aborts before touching the host if a lab is active there, and stops if a lab is still active after its reset.
- Labs are tested one at a time, never in parallel and never two runs against the same host: labctl keeps a single `.current_lab`.
- It deletes nothing on the host except through the lab's own `cleanup.sh` and its own temporary directory. Afterwards `rpm -V linux-labs` lists the replaced files; `dnf reinstall linux-labs` restores the packaged versions.
- Runtime tests do not run in CI: most labs need systemd, firewalld or SELinux. Results go into the release notes (for example "Verified on Rocky 8.7 workstation: N of 55 PASS"), not into commits or files in git.

`test_static_ips.sh` is an older manual smoke test for the node-IP helpers; it sources the library from `/root/linux-labs/`, so it only runs from a checkout at that path.

## Building the RPM

```bash
scripts/build-rpm-linux.sh                    # on an EL8 host with rpm-build and sudo installed
scripts/build-rpm-linux.sh --deploy user@host # same, then scp + dnf reinstall on that host
```

The spec is in git at `rpm/linux-labs.spec`, and its `Version:` is the release version. The script reads `Name:`/`Version:` from it, recreates `packaging/rpmbuild/SOURCES/<name>-<version>/` from `labs/` (without any `solve.sh`), `src/etc`, `src/usr` and `src/opt/linux-labs/lib`, copies the spec into `packaging/rpmbuild/SPECS/`, tars the sources and runs `rpmbuild`. Each lab ships `setup.sh`, `grade.sh`, `cleanup.sh`, `description.txt`, `task.txt` and `solution.md`; `%install` deletes any `solve.sh` that reaches the buildroot as a second guard. `packaging/` is a gitignored local build directory (also holds `test-logs/`). Edit `labs/`, `src/` and `rpm/linux-labs.spec`, never the copies under `packaging/`.

`Release: 1` has no `%{?dist}`: one noarch RPM built on EL8 serves EL8 and EL9. `%check` runs `visudo -cf` on the sudoers rule, so `sudo` is a BuildRequires. labctl is installed 0755; there is no setuid (the kernel ignores it on scripts, sudo gives root).

Without `--deploy` the script contacts no host. With `--deploy root@10.0.0.149` it copies the RPM to the author's personal test VM and reinstalls it there; ask before using that.

## Releases

`.github/workflows/rpm.yml` runs `scripts/check-labs.sh` on `ubuntu-latest` (job `check`, shellcheck from apt), then builds in a `rockylinux/rockylinux:8` container on pushes to `main` and on PRs, and smoke-tests the RPM on Rocky 8 and 9 (`labctl list`, `grading.sh` present, no `solve.sh` shipped, mode 755, `visudo -c`). Pushing a tag `vX.Y.Z` that matches the spec `Version:` also signs the RPM (`scripts/sign-rpm.sh`, secrets `RPM_GPG_PRIVATE_KEY` and `RPM_GPG_PASSPHRASE`, key fingerprint `2C8B8EF02609AF36359D2D7E603E53FE67BA2549`, public half in `RPM-GPG-KEY-linux-labs`), installs it on Rocky 9 with `gpgcheck=1`, creates a GitHub Release, and adds the RPM to the dnf repo on the `gh-pages` branch (`scripts/update-pages.sh`, `createrepo_c --update`). Pages serves that at `https://matej-basic.github.io/linux-labs/`, together with `install.sh` as `/install`. A tag that does not match `Version:` fails the run. To release: bump `Version:`, add a `%changelog` entry, push to `main`, then push the tag.

## labctl behaviour during the migration

- `start`: for a converted lab, runs `setup.sh`; if it fails, prints `Error: setup of lab <id> failed (exit N). The lab was not started.` to stderr and exits with that status. Otherwise writes `.current_lab` and prints the header and task. For a legacy lab, runs `setup.sh` (which prints its own banner) and writes `.current_lab` as before, ignoring the setup status. Both exit 0 on success.
- `task`: converted labs only; for a legacy lab it tells the student to use `sudo labctl start`. Needs no root and changes nothing.
- `reset`: runs `cleanup.sh` and removes `.current_lab`; for a converted lab a failed cleanup is reported and its status returned.
- `grade`, `list`, `solution` and `configure` are unchanged. labctl output is plain ASCII.
- The `[LAB:...]` prompt comes from `PROMPT_COMMAND` in `/etc/profile.d/labctl.sh` reading `.current_lab` at every prompt; labctl does not source it.

## Known issues

- There is no "Tested clustering-NN" commit for the clustering labs, and SSH key access to servera, serverb and serverc (10.0.0.189 to .191) still fails, so the multi-node labs cannot be runtime-tested yet.
- Earlier "Tested <lab>." / "Confirmed <lab> works as intended" commits predate several bulk changes and do not count as evidence; `test-lab.sh` runs replace them.
- `brainstorm/` holds design notes and plans (class dashboard, break-fix labs, hub/spoke multi-node, the framework 2.0 plan). They are plans, not implemented behaviour.
