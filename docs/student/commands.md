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
| `labctl solution <lab>` | shows the reference solution (press q to leave) | no |
| `sudo labctl reset <lab>` | undoes the lab and your changes, ends the lab | yes |
| `labctl help` | prints a short summary of the commands | no |

`--level` and `--course` can be combined, for example
`labctl list --course aoos --level beginner`. Upper or lower case does
not matter.

`labctl grade` needs root rights to check the system, but you run it
without sudo: labctl gets the rights by itself.

`labctl grade` exits with status 0 when every requirement is met and 1
otherwise. `echo $?` right after it shows the status.

Your teacher may also use `labctl configure`, which sets up labs that
run on several machines. You do not need it for the other labs.

Other guides on this machine are in /usr/share/doc/linux-labs/:
getting-started.md and troubleshooting.md.
