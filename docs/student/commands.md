# labctl commands

The full reference is the manual page:

    man labctl

| Command | What it does | sudo |
|---|---|---|
| `labctl list` | lists all labs with what you do in them | no |
| `labctl list --level beginner` | only labs of one level: beginner, intermediate or advanced | no |
| `labctl list --course aoos` | only the labs of one course | no |
| `sudo labctl start <lab>` | prepares the system and prints the task | yes |
| `labctl task <lab>` | prints the task again, changes nothing | no |
| `labctl grade <lab>` | checks your work, one PASS or FAIL line per requirement | no |
| `labctl hint <lab>` | shows the next hint; each call adds one, and the count is reset when the lab is started or reset | no |
| `labctl solution <lab>` | asks "Continue? [y/N]", then shows the reference solution (press q to leave) | no |
| `labctl solution <lab> --yes` | shows the reference solution without asking | no |
| `sudo labctl reset <lab>` | undoes the lab and your changes, ends the lab | yes |
| `labctl help` | prints a short summary of the commands | no |

`--level` and `--course` can be combined, for example
`labctl list --course aoos --level beginner`. Upper or lower case does
not matter.

`labctl grade` needs root rights to check the system, but you run it
without sudo: labctl gets the rights by itself.

One lab is active at a time. Finish it with `sudo labctl reset <lab>`
before you start the next one; `sudo labctl start` refuses another lab
until then. Starting the active lab again is allowed and prepares it
from the beginning.

Run all labctl commands on the workstation, also for a lab that runs
on servera. labctl does the setup, grading and reset on servera by
itself; you only log in there to do the work.

`labctl grade` exits with status 0 when every requirement is met and 1
otherwise. `echo $?` right after it shows the status.

Your teacher may also use `labctl configure`, which sets up labs that
run on several machines. You do not need it for the other labs.

Other guides on this machine are in /usr/share/doc/linux-labs/:
getting-started.md and troubleshooting.md.
