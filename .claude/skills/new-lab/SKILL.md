---
name: new-lab
description: Create a new labctl lab in the linux-labs repo (Rocky/RHEL RHCSA-style labs under labs/<topic>-NN, lab framework 2.0) - pick an idea from docs/lab-ideas.md, settle the graded end state with the user, have a subagent build the seven lab files, review them, runtime-test on the workstation VM and update the records (docs/lab-ideas.md and the generated catalog). Use when the user invokes /new-lab or says "new lab", "create a lab", "next lab from the lab ideas", "implement lab <id>" while working in linux-labs. Not for Markdown course labs in university-labs; that is generate-lab.
---

# New lab

Build one new framework 2.0 lab per run. The main session picks the lab,
settles the design with the user, delegates the build, reviews the files
and runs the runtime test. `docs/author/framework.md` is the binding
spec (imported by `CLAUDE.md`) and wins over this skill; read it before
step 1 if it is not already in context. `docs/author/testing.md` covers
the static and runtime tests. `labs/files-04/` is the reference lab.

## Rules for everything the lab ships

- English, plain printable ASCII, 72 columns (URL lines exempt).
- Neutral imperative tone, one fact per sentence. No em or en dashes, no
  emoji, no exclamation marks, no capitals for emphasis.
- `task.txt` describes the end state, never the solution: no commands,
  options, globs or brace patterns that solve a graded task.
  `solution.md` is the only place for commands.
- No names of real people (students, collaborators, the author) in lab
  content, metadata, `description.txt` or comments.
- Never read, copy or touch `.config/` (local credentials).

## Lab test environment

Workstation `10.0.0.188`: Rocky 8.7, SELinux enforcing, `linux-labs` RPM
installed, user `student`, root SSH key access. `ens192` carries the
default route and is never touched. `ens224` and `ens256` are free NICs
on an isolated network for network labs. servera, serverb and serverc
(10.0.0.189 to .191) exist, but SSH key access to them has been failing
(see Known issues in `CLAUDE.md`); check before promising a multi-node test.

## 1. Pick the lab

- With an argument: a lab id (`users-04`) or a topic (`ssh keys`). Find
  the matching entry in `docs/lab-ideas.md`.
- Without one: list 3 to 5 proposed ideas that fit a single Rocky VM
  with no internet dependency, and recommend one with a one-line reason.
  Prefer topics that extend an existing category before new categories.
- Determine the id: `ls -d labs/<topic>-*` (include untracked
  directories, another session may be building one) and take the next
  free two-digit number. The id prefix follows the existing labs
  (`webserver`, `mysql`, `lb`), not necessarily the name in
  `docs/lab-ideas.md`.
- Map it to a `category` from the list in `docs/author/framework.md`. A new category
  needs `CATEGORIES` in `scripts/check-labs.sh` changed; tell the user
  and get approval before anything outside `labs/<id>/` is edited.

## 2. Grill the user briefly

One question at a time, each with your recommended answer. Ask only what
the repo cannot answer; explore `labs/`, `docs/author/` and similar labs
instead of asking about conventions. Cover, as relevant:

1. Objective and the exact graded end state (the criteria list).
2. Level: Beginner, Intermediate or Advanced.
3. `course` and `course_lab` keys, or none.
4. Reboot needed to prove persistence (`# solve: reboot`).
5. Free NIC needed (network lab rules apply).
6. Multiple nodes (needs `TOPOLOGY`, `load-config.sh`, servera/b/c).
7. Extra packages, repos (`--enablerepo=ha`) or internet access.
8. Rocky 8 and 9 both supported, or one only, and what differs.

Stop as soon as the user says it is enough; settle the rest yourself
and list it as assumptions. Summarise the agreed design in five to ten
lines before step 3.

## 3. Delegate the build

Spawn one `general-purpose` agent. Model: `sonnet` by default, `opus`
for multi-node labs, network labs or anything with tricky cleanup.
Fill in `builder-brief.md` from this directory and pass it as the
prompt. The brief is self-contained: the agent has none of this
conversation. Wait for it; do not write lab files yourself meanwhile.

## 4. Review the files, not the report

Read all seven files in `labs/<id>/` end to end, then check:

- `git status --porcelain` shows changes only under `labs/<id>/`.
- Every `TASKS` item maps to a `grade.sh` criterion and back. Nothing
  graded is missing from the task; nothing in the task goes ungraded
  (that belongs in `PRACTICE (not graded)`).
- `task.txt` gives no solving commands, options, globs or patterns, not
  even mid-sentence (the checker misses those).
- Following `solution.md` satisfies every criterion; `solve.sh` does the
  same steps in the same order, with `[user]` steps via `run_as_student`.
- `cleanup.sh` removes everything setup and the solution create: files,
  users, packages, services, firewall rules, SELinux changes, NM
  profiles, the state file. It tolerates a lab that was never started.
- `setup.sh` is silent, idempotent, `set -eu`, fails with a stderr
  message. Network labs detect free NICs and never touch `ens192`.
- Rocky 8 vs 9 differences are handled or stated in `NOTES`.
- Run `bash -n labs/<id>/*.sh` and `scripts/check-labs.sh --strict <id>`
  yourself; both must pass.

Send defects back to the same agent once with `SendMessage`, listing
each defect and how you found it. If the second round still fails,
fix it yourself or stop and tell the user.

## 5. Runtime test

```bash
scripts/test-lab.sh 10.0.0.188 <id>
```

Strictly one lab at a time. Never run it in parallel with another test,
another session's test, or a lab a person is working through on the
host: labctl keeps one `.current_lab` and the `[LAB:...]` prompt. If the
script aborts because a lab is active, report that and stop; do not
reset someone else's lab. Multi-node labs need servera/b/c; if SSH to
them fails, say so and stop at the static layer. On failure, read the
log under `packaging/test-logs/`, send the defect to the agent, re-run
check and test. Exit 2 (skipped) is not a pass.

## 6. Update the records

- Remove the idea from `docs/lab-ideas.md` and run
  `scripts/gen-catalog.sh`, which regenerates
  `docs/catalog.md` from the `description.txt` files.
- Check that `description.txt` has the right `needs:` line (internet,
  reboot, free-nic, nodes=N; omit the key when the lab needs nothing);
  `scripts/check-labs.sh` cross-checks reboot and nodes.

## 7. Report

Tell the user: the lab id and files, the design assumptions, the
`check-labs.sh --strict` result, and the `test-lab.sh` PASS/FAIL table
(or why it did not run). Name anything that needs a change outside
`labs/<id>/` (framework, checker allowlist, categories) as a proposal.
Do not commit, push or tag. Offer `/ship`.
