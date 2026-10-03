# scripting-01: Bash scripts with arguments, conditions and loops

## Hints

Task 2: filecount

1. The special parameter for the number of arguments tells you
   whether the script got exactly one. Read man bash, sections
   Positional Parameters and Special Parameters.
2. The test command has operators for "is a directory" and "is a
   regular file". Read man bash, section CONDITIONAL EXPRESSIONS.
   Send a message to standard error by redirecting it to file
   descriptor 2, and end the script with the exit builtin.
3. A for loop over the pathname pattern of all names in the directory
   skips hidden names and returns them sorted. The command wc counts
   lines, and it prints only the number when it reads the file from
   standard input. Add the counts with shell arithmetic.

Task 3: userinfo

1. A for loop without a word list loops over all arguments in order.
   Read man bash, section Compound Commands.
2. The command getent with the passwd database prints the passwd
   entry of one user and exits non-zero when the user does not exist.
3. The UID is field 3 and the login shell is field 7 of a passwd
   entry, separated by colons. Keep a variable for the exit status
   and set it to 1 when a user is missing.

## Solution

1. [sudo] Open /usr/local/bin/filecount in an editor as root:

   ```bash
   sudo vi /usr/local/bin/filecount
   ```

   Enter this content. The code blocks in this file are indented by
   three spaces; in the script every line starts in column 0, so the
   file starts with the two characters #! of #!/bin/bash.

   ```bash
   #!/bin/bash
   # Print the number of lines of every regular file in a directory.
   if [ "$#" -ne 1 ]; then
     echo "Usage: filecount <directory>" >&2
     exit 2
   fi
   dir=$1
   if [ ! -d "$dir" ]; then
     echo "Not a directory: $dir" >&2
     exit 1
   fi
   total=0
   for path in "$dir"/*; do
     [ -f "$path" ] || continue
     lines=$(wc -l < "$path")
     echo "${path##*/} $lines"
     total=$((total + lines))
   done
   echo "total $total"
   ```

2. [sudo] Open /usr/local/bin/userinfo the same way:

   ```bash
   sudo vi /usr/local/bin/userinfo
   ```

   Enter this content:

   ```bash
   #!/bin/bash
   # Report whether users exist, with their UID and login shell.
   if [ "$#" -eq 0 ]; then
     echo "Usage: userinfo <user>..." >&2
     exit 2
   fi
   status=0
   for user; do
     if entry=$(getent passwd "$user"); then
       uid=$(echo "$entry" | cut -d: -f3)
       shell=$(echo "$entry" | cut -d: -f7)
       echo "$user exists $uid $shell"
     else
       echo "$user missing"
       status=1
     fi
   done
   exit "$status"
   ```

3. [sudo] Make both scripts executable for every user:

   ```bash
   sudo chmod 755 /usr/local/bin/filecount /usr/local/bin/userinfo
   ```

4. [user] Test them as your own user:

   ```bash
   filecount /srv/scripting/reports; echo "exit $?"
   LC_ALL=C filecount /srv/scripting/configs
   filecount /srv/scripting/empty
   filecount; echo "exit $?"
   filecount /etc/hostname; echo "exit $?"
   userinfo root nosuchuser "$USER"; echo "exit $?"
   userinfo; echo "exit $?"
   ```

## Verification

```bash
ls -l /usr/local/bin/filecount /usr/local/bin/userinfo
labctl grade scripting-01
```

## Explanation

`$#` is the number of arguments, so one test covers both "no
argument" and "too many". `>&2` sends the message to standard error,
and `exit` with a number sets the status the caller sees in `$?`.

The pattern `"$dir"/*` expands to the names in the directory, sorted
in the order of the current locale and without hidden names. `[ -f ]`
then skips directories, so files inside subdirectories are never
counted. The grader runs with the C locale, where the order is byte
order: web1.conf, web10.conf, web2.conf. In the en_US.UTF-8 locale
the same pattern puts web10.conf first, so test with LC_ALL=C.
In an empty directory the pattern stays unexpanded, `[ -f ]` fails
for it and only the total is printed. `wc -l < file` prints the
number only; `wc -l file` would print the file name as well.
`${path##*/}` removes everything up to the last slash.

`for user; do` loops over all arguments in order, like
`for user in "$@"`. getent exits with status 2 when the user does not
exist, which the `if` uses directly. The status variable starts at 0
and becomes 1 at the first missing user, so the script still reports
every user before it exits.

Install the scripts with sudo, but run them as your normal user: they
read only world-readable files and the passwd database.
