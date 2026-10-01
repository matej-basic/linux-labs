# Builder brief template

Fill in the `<...>` fields and pass everything below the line as the
agent prompt. Delete lines that do not apply.

---

Build the new lab `<id>` in the linux-labs repo at
/Users/matej/Documents/git/linux-labs, following lab framework 2.0.

Read first, completely: `docs/author/framework.md` (the binding spec: lab contract,
"Describe the end state, never the solution", grading library, network
labs, solve.sh directives), all seven files of `labs/files-04/` (the
reference lab), `src/opt/linux-labs/lib/grading.sh` and
`scripts/solve-lib.sh`. Look at `<similar existing lab>` for the topic.

## Agreed design

- id: `<id>`, title: `<title, sentence case, at most 60 chars>`
- category: `<category from docs/author/framework.md>`, complexity: `<Level>`
- objective: `<one sentence>`
- course / course_lab: `<code> / <NN>` or none
- Graded end state, one criterion each:
  1. `<criterion>`
  2. `<criterion>`
- Lab user works as: `<student without sudo | with sudo>`
- Reboot: `<yes, add "# solve: reboot" | no>`
- Network: `<uses one free NIC, never ens192 | none>`
- Nodes: `<single-node | N nodes, TOPOLOGY section, load-config.sh>`
- Packages / repos / internet: `<list or none>`
- needs: `<value for the description.txt needs: line, or none>`
- Rocky 8 and 9: `<both | 8 only, because ...>`; differences: `<...>`

## Create exactly these files in labs/<id>/

`description.txt`, `task.txt`, `setup.sh`, `grade.sh`, `cleanup.sh`,
`solution.md`, `solve.sh`. Nothing else. The four scripts start with
`#!/bin/bash` and are executable (`chmod 755`).

- `description.txt`: add `needs:` as the last line when the lab needs
  something from the environment, items comma separated in this order:
  `internet` (setup or solution installs or downloads), `reboot` (must
  match `# solve: reboot`), `free-nic` (uses a free network interface),
  `nodes=N` (N >= 2, must match the TOPOLOGY section). Omit the key when
  the lab needs nothing.
- `task.txt`: end state only. `TASKS` lists exactly what `grade.sh`
  checks. No commands, options, globs or brace patterns that solve or
  approach a graded task; man page names in `NOTES` are fine.
- `setup.sh`: silent on success, `set -eu`, idempotent, stderr message
  and non-zero exit on failure, state in `/opt/linux-labs/state/<id>`
  mode 0644 if the grader needs it.
- `grade.sh`: only `lib/grading.sh` (`grade_begin`, `criterion`,
  `criterion_result`, `grade_require_state`, `grade_end`), no `set -e`,
  no extra output, same result as student and as root.
- `cleanup.sh`: undoes setup and the solution, including packages,
  services, firewall, SELinux and NetworkManager changes and the state
  file; never fails on a lab that was not started.
- `solution.md`: `# <id>: <title>`, then `## Solution` (steps with
  `[user]` or `[sudo]`), `## Verification`, `## Explanation`.
- `solve.sh`: same steps as `solution.md`, `set -euo pipefail`, sources
  `solve-lib.sh`, `[user]` steps through `run_as_student`, at least one
  `# solve:` directive (path, package, reboot or none).

Text rules for every file: English, plain printable ASCII, lines at
most 72 columns, neutral imperative tone, no em or en dashes, no emoji,
no exclamation marks, no names of real people.

## Verify before reporting

```bash
bash -n labs/<id>/*.sh
scripts/check-labs.sh --strict <id>
```

Both must exit 0. Fix the cause of shellcheck findings; disable a
warning only on its line with a reason.

## Boundaries

- Change nothing outside `labs/<id>/`. Other agents are editing other
  labs, the records (`docs/lab-ideas.md`, the generated `docs/catalog.md`) are updated by the main session.
- If the framework, `check-labs.sh`, its allowlist or a library needs a
  change, describe it in the report instead of making it.
- No git operations (no add, commit, push, chmod via git).
- Do not run `test-lab.sh` and do not contact any host.
- Never read or touch `.config/`.
- Do not ask questions; decide, and list the assumption.

## Report

Files created, the criteria list from `grade.sh`, the exit status and
output of both verify commands, Rocky 8/9 notes, assumptions, and any
framework changes you think are needed.
