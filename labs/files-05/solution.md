# files-05: Finding files and searching text

## Hints

1. One command searches a directory tree and tests every file it
   meets: by type, owner, size, permission bits and modification
   time. Read man find, section TESTS, and the part about numeric
   arguments with a plus or minus sign.
2. A search as your normal user also prints error messages for the
   directories it cannot read. Those go to standard error, while the
   results go to standard output. Read man bash, section REDIRECTION,
   to send each stream to its own file or to discard one of them.
3. The command grep matches regular expressions. A caret anchors a
   pattern at the start of the line, and an option matches whole
   words only. The output of one grep can be filtered by a second
   one.
4. The command wc counts lines. The SUID bit is the permission value
   4000, and find can test for a bit regardless of the other bits.

## Solution

1. [user] Save the regular files of builder that are larger than
   1 MiB. The searches in steps 1 to 4 run as your user, so error
   messages about unreadable directories are discarded:

   ```bash
   find /srv/search -type f -user builder -size +1M 2>/dev/null \
     > ~/answers/large-files.txt
   ```

2. [user] Save the regular files under /srv/search/projects that were
   last modified more than 30 days ago:

   ```bash
   find /srv/search/projects -type f -mtime +30 2>/dev/null \
     > ~/answers/old-files.txt
   ```

3. [user] Save the regular files with the SUID bit:

   ```bash
   find /srv/search -type f -perm -4000 2>/dev/null \
     > ~/answers/setuid.txt
   ```

4. [user] Count the symbolic links:

   ```bash
   find /srv/search -type l 2>/dev/null | wc -l \
     > ~/answers/link-count.txt
   ```

5. [user] Save the lines that begin with ERROR and contain the word
   disk:

   ```bash
   grep '^ERROR' /srv/search/logs/app.log | grep -w disk \
     > ~/answers/errors.txt
   ```

6. [user] Search for report.txt and send the results and the error
   messages to separate files:

   ```bash
   find /srv/search -name report.txt \
     > ~/answers/report-files.txt 2> ~/answers/denied.txt
   ```

## Verification

```bash
cat ~/answers/large-files.txt ~/answers/errors.txt
cat ~/answers/denied.txt
labctl grade files-05
```

## Explanation

The test -size +1M rounds every file size up to whole MiB before it
compares, so it matches files larger than 1048576 bytes. The file of
exactly 1 MiB is not included, while the file of 1100 KiB is. Be
careful with -size -1M: after rounding up it matches only empty files.
The test -mtime +30 matches files whose age in whole days is more than
30. The test -perm -4000 matches any file that has at least the SUID
bit, whatever its other permission bits are; -perm 4000 without the
dash would require the mode to be exactly 4000.

Symbolic links are not regular files, so -type f leaves them out of
the lists, and -type l counts them, including the broken one.

In the log, the caret makes ERROR count only in the first column, so
the line with a leading space and the INFO line that mentions ERROR
are left out. The option -w of grep rejects disks and diskless, and
grep is case sensitive by default, so the lines with error and Disk
are left out as well.

The command find exits with status 1 when it meets a directory it
cannot read. Its error messages go to standard error (2>), its
results to standard output (>). The search in step 6 must run without
sudo; as root it would find every report.txt and print no errors.
