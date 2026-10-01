# Lab framework 2.0

This is the contract every lab in `labs/` follows: which files a lab has, what each one may print, how grading works and how the text is written. `scripts/check-labs.sh` enforces most of it (see [testing.md](testing.md)); reviewers catch the rest. `CLAUDE.md` imports this file, so the rules are the same for people and for Claude.

All 55 labs in `labs/` are converted: each has a `task.txt`. A lab without `task.txt` would be a legacy lab and keeps working through the fallbacks described in "labctl behaviour during the migration" at the end of this file. `files-04` is the reference lab: when in doubt, copy its structure.

## Lab contract (framework 2.0)

A converted lab directory has exactly these seven files and nothing else:

| File | Shipped | Called by | Purpose |
|---|---|---|---|
| `setup.sh` | yes | `labctl start` (as root) | prepares the system, prints nothing |
| `grade.sh` | yes | `labctl grade` (always as root; labctl re-runs itself through sudo for the student) | checks the final state with `lib/grading.sh` |
| `cleanup.sh` | yes | `labctl reset` (as root) | undoes setup and solution |
| `description.txt` | yes | `labctl list`, task header | metadata |
| `task.txt` | yes | `labctl start`, `labctl task` | the task text shown to the student |
| `solution.md` | yes | `labctl solution`, `labctl hint` | optional hints and the reference solution for students |
| `solve.sh` | no | `scripts/test-lab.sh` (as root) | automatic solver, same steps as `solution.md` |

`setup.sh`, `grade.sh`, `cleanup.sh` and `solve.sh` start with `#!/bin/bash` and are executable on disk and in git (mode `100755`; `git update-index --chmod=+x` if needed). labctl only accepts a lab name if at least one of the three shipped scripts is executable on the installed system; the spec's `%install` also runs `chmod 0755` on every `*.sh`. All shipped text files are plain ASCII.

When adding a lab, remove its idea from `docs/lab-ideas.md` and run `scripts/gen-catalog.sh`, which regenerates `docs/catalog.md` from the `description.txt` files. Labs are built and tested one at a time (see [testing.md](testing.md)).

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
- `needs` (optional, omit it when the lab needs nothing special): what the student environment must provide, separated by a comma and a space, in this fixed order: `internet` (the lab installs packages or downloads files), `reboot` (the solution reboots the machine, so it must match `# solve: reboot` in `solve.sh`), `free-nic` (a network interface with no connection, used by network labs), `nodes=N` (the lab uses N nodes, N at least 2, so it must match a `TOPOLOGY` section in `task.txt`). `labctl start` and `labctl task` show it as a `Needs:` line; the catalog has a column for it. Example: `needs: internet, nodes=3`.

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
- `GRADING` contains the line `  labctl grade <id>` (no `sudo`: `labctl grade` elevates itself through the sudoers rule).
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
- Per-lab state (owner name, start transaction id, generated values) goes in the file `/opt/linux-labs/state/<lab>` (or a directory of that name), mode `0644`. `cleanup.sh` removes it.
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
- If the lab has a state file, call `grade_require_state` right after `grade_begin`. `labctl grade` always runs `grade.sh` as root (a student call re-executes through `sudo -n`), so graders may read root-only files and configuration. Do not add a sudo re-exec inside `grade.sh`.
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

The clustering labs are a 3-node Pacemaker/Corosync series (basic cluster, STONITH fencing, quorum and split-brain protection). Use `pcs` and `crm_node` in scripts, not `crm`: crmsh is not installed on the student VMs. Pacemaker, pcs and fence agents come from the High Availability repo, which is disabled by default: its id is `ha` on EL8 and `highavailability` on EL9 (`dnf install --enablerepo=ha ...` on EL8). Nodes have no root SSH to each other, so solutions copy files between nodes through the workstation. `fence_virsh` in clustering-02 cannot reach a real hypervisor in this environment; the solution sets `migration-threshold=INFINITY` so failing fence devices don't block the resource.

Config precedence in `load_lab_config`: environment variables, then the config file, then defaults. The file is `/etc/linux-labs/config` if it exists, otherwise `~/.config/linux-labs/config` of the invoking user: under sudo that is `SUDO_USER`'s home, so `sudo labctl start` and the root-run grader read the same file that `labctl configure` saved (labctl and `load-config.sh` share this lookup; keep them in sync). Writing the system config needs `sudo labctl configure`; without root labctl refuses instead of failing silently. `load-config.sh` is safe under `set -euo pipefail`, and `run_on_node`/`test_node_connectivity` use `BatchMode=yes` and a connect timeout, so a missing key fails fast instead of waiting on a password prompt. Node IPs come from `NODE_IPS` (space-separated static list) if set; otherwise node N is `<network base>.<N+9>`. Defaults (network `172.25.250.0/24`, gateway `.254`, the RH classroom bastion) are duplicated in `labctl`, `load-config.sh`, `config.template` and the docs (`docs/teacher/multi-node.md`, `docs/teacher/environment.md`); change them everywhere together.

## solution.md

Same ASCII, width (72 columns, URL lines exempt), whitespace and tone rules as `task.txt`. Structure:

````
# files-04: Brace expansion and file organisation

## Hints

1. The shell can generate many words from one pattern before a command
   runs. Read man bash, section Brace Expansion.
2. The command mkdir has an option that creates missing parent
   directories. The shell expands the same kind of pattern for it.

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

- Line 1 is `# <id>: <title>` with the title from `description.txt`. The only `##` headings are `Hints` (optional), `Solution`, `Verification`, `Explanation`, in that order. `###` subheadings inside `Solution` are allowed (for example one per node).
- Steps are numbered `1.`, `2.`, ... in column 0, without gaps, and each starts with `[user]` (run as the normal lab user, no sudo) or `[sudo]` (needs root; the commands carry `sudo`). Code blocks are indented three spaces under their step.
- `## Verification` runs `labctl grade <id>`; other read-only commands may come before it.
- `## Explanation` is short prose, no step list.

### Hints

`## Hints` is optional; a lab without it works, and `labctl hint` says the lab has no hints. `labctl hint <id>` reads only this section. The rules, all checked by `check-labs.sh`:

- The section comes before `## Solution`, with one blank line after the heading. Contents are numbered items in column 0 (`1. `, `2. `, ...) from 1 without gaps. A hint that wraps continues on lines indented by three spaces. Blank lines between items are allowed. No code fences, no other kinds of lines.
- 2 to 4 hints, from vague to concrete: a direction or concept first, then the tool or man page section, then optionally the specific option or structure.
- The hints follow the rule for `task.txt` ("Describe the end state, never the solution"): no complete solving command, no brace pattern, no glob. Command and option names are allowed in prose. The same pattern check as for `task.txt` runs over the section, so an item or continuation line must not start with a command name followed by an argument (write "The command mkdir has an option ..." instead of "mkdir has an option ..."). The `scripts/check-labs.allow` file works for hints too, with entries in the form `<lab>: <line without its indent>`. Ready-to-copy lines belong in `## Solution`.
- The text rules of the whole file apply (ASCII, 72 columns, no exclamation marks).
- A lab with independent parts may group its hints. A line in column 0 that starts with `Task N:` opens a group, for example `Task 3: the directory tree`. Numbering restarts at 1 in each group and each group has 2 to 4 hints. Hints before the first group line are not allowed once groups are used.

Example with groups:

```
## Hints

Task 2: the files

1. First hint for task 2.
2. Second hint for task 2.

Task 3: the tree

1. First hint for task 3.
2. Second hint for task 3.
```

`labctl hint` numbers the hints 1 to M across groups and prints the group line above the first hint of each group. Each call shows all hints given so far plus one more; the count is kept in `~/.local/state/linux-labs/hints/<id>` of the user and removed by `labctl start` and `labctl reset`. This is a learning aid on the honour system: students can read `solution.md` anyway.

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

## known-issues.md

An optional file `labs/<id>/known-issues.md` records what a lab cannot fix by itself. It sits next to the lab so that a runtime test agent writes only inside `labs/<id>/`. Its readers are teachers and authors, and it can reveal parts of the solution, so it stays in the repo and is not shipped in the RPM (like `solve.sh`).

Format: the heading `# <id>: known issues`, then one list entry per issue in this fixed shape:

```
# example-01: known issues

- 2026-10-01 | rocky9 | workaround | The minimal install has no tar
  package, so setup.sh installs it before it builds the lab data.
- 2026-09-14 | all | open | Package mirrors can be slow at the start of
  a class, and the package install in the solution then takes several
  minutes.
```

- The four fields are separated by ` | `: the date of the entry as `YYYY-MM-DD`, the release (`rocky8`, `rocky9` or `all`), the status, and the description.
- Status `workaround` when the lab already works around the problem, `open` when a student can still hit it, `fixed` when the cause is gone. Fixed entries stay as history.
- The description is plain prose with the same text rules as `task.txt`, and it contains no solving commands. Continuation lines are indented two spaces.
- The catalog shows the number of `open` and `workaround` entries per lab, with a link to the file; `fixed` entries are not counted. Course sheets will list the entries in full later.
- What belongs in the file and who writes it is in [testing.md](testing.md) ("Known issues").

Planned, not yet implemented: `check-labs.sh` does not validate the file yet (line shape, date, release, status, text rules), and it does not accept it either: until the file set criterion is extended, a lab with `known-issues.md` fails "Lab directory has exactly the 2.0 file set". The catalog column does not exist yet, and `build-rpm-linux.sh` and the spec do not yet leave the file out of the RPM. Add the first entry together with those changes.

## labctl behaviour during the migration

- `start`: for a converted lab, runs `setup.sh`; if it fails, prints `Error: setup of lab <id> failed (exit N). The lab was not started.` to stderr and exits with that status. Otherwise writes `.current_lab` and prints the header and task. For a legacy lab, runs `setup.sh` (which prints its own banner) and writes `.current_lab` as before, ignoring the setup status. Both exit 0 on success.
- `task`: converted labs only; for a legacy lab it tells the student to use `sudo labctl start`. Needs no root and changes nothing.
- `reset`: runs `cleanup.sh` and removes `.current_lab`; for a converted lab a failed cleanup is reported and its status returned.
- `start` and `task` end with `Stuck? Run labctl hint <id>` when `solution.md` has a `## Hints` section. `start` and `reset` delete the hint counter of the calling user (`SUDO_USER`).
- `hint <id>` shows the hints given so far plus the next one; `hint <id> --all` shows all of them and leaves the counter alone. `solution <id>` asks "This shows the full solution. Continue? [y/N]" when stdin and stdout are terminals; `--yes` skips the question, and without a terminal (pipes, scripts, `test-lab.sh`) nothing is asked.
- `grade` and `configure` are unchanged; `list` gained the `--course` and `--level` filters. labctl output is plain ASCII.
- The `[LAB:...]` prompt comes from `PROMPT_COMMAND` in `/etc/profile.d/labctl.sh` reading `.current_lab` at every prompt; labctl does not source it.
