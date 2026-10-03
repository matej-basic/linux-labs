# files-08: Text processing reports from a web server log

## Hints

1. Each report is one pipeline: a command that picks the field you
   need, then sorting, counting or summing, and a redirection into the
   report file. Read man bash, sections Pipelines and REDIRECTION.
2. The commands cut and awk print single fields of each line. awk can
   also compare a field with a value and add numbers, so it can count
   the 404 status codes and sum the sizes without other tools.
3. The command uniq counts repeated lines only when they are adjacent,
   so sort before it. The command sort has options for numeric order,
   reverse order, a field separator, a sort key and unique lines.
4. Byte order needs the C locale for the sort itself: set the
   variable LC_ALL to C for that command. The output of uniq with
   counts starts with spaces, which awk removes when it prints the
   two fields again.

## Solution

1. [user] Create the reports directory:

   ```bash
   mkdir -p ~/reports
   cd /srv/textlab
   ```

2. [user] The 5 busiest client addresses, without leading spaces:

   ```bash
   cut -d ' ' -f 1 access.log | sort | uniq -c | sort -rn |
     head -n 5 | awk '{ print $1, $2 }' > ~/reports/top-ips.txt
   ```

3. [user] The number of requests with status code 404:

   ```bash
   awk '$9 == 404' access.log | wc -l > ~/reports/not-found.txt
   ```

4. [user] Every distinct path in byte order:

   ```bash
   awk '{ print $7 }' access.log | LC_ALL=C sort -u \
     > ~/reports/paths.txt
   ```

5. [user] The total of the response sizes:

   ```bash
   awk '$10 != "-" { sum += $10 } END { print sum }' access.log \
     > ~/reports/bytes.txt
   ```

6. [user] The /bin/bash accounts, sorted by UID:

   ```bash
   tail -n +2 accounts.csv |
     awk -F, '$4 == "/bin/bash" { print $1 ":" $2 }' |
     sort -t : -k 2,2n > ~/reports/bash-users.txt
   ```

## Verification

```bash
cat ~/reports/top-ips.txt ~/reports/not-found.txt ~/reports/bytes.txt
head ~/reports/paths.txt ~/reports/bash-users.txt
labctl grade files-08
```

## Explanation

`uniq -c` counts only adjacent equal lines, so the addresses are
sorted first, and `sort -rn` then puts the highest count on top. The
counts come out right-aligned with leading spaces; `awk '{ print $1,
$2 }'` prints the two fields again with one space between them.

A search for the text 404 with grep counts too many lines: /robots.txt
is 404 bytes long, so its lines have 404 in the size field. Comparing
field 9 counts only the status code. `wc -l` reads from the pipe and
prints the number alone.

The default locale of the account is en_US.UTF-8, where sort ignores
case and punctuation in its first pass and puts /about.html next to
/About.html. `LC_ALL=C` sorts by byte value: every uppercase letter
comes before every lowercase one, and `-` and `.` come before `_`.

awk treats - as the number 0, but the condition makes the rule
explicit. On accounts.csv the shell must equal /bin/bash exactly:
searching for bash would also match /usr/bin/bash and the user
bashir. `sort -t : -k 2,2n` sorts numerically on the UID, where a
plain sort would put 10011 before 987.
