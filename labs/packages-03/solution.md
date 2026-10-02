# packages-03: Package file lists

## Hints

1. The RPM database knows which files each installed package owns.
   Query it instead of searching the file system.
2. Read man rpm, section Query Options. One option lists the files
   of a package, another reads from a package file instead.
3. The query mode is -q and the option -l lists files. Use shell
   redirection to write the output to /tmp/curl-files.txt. No root
   is needed for the query.

## Solution

1. [sudo] Make sure the curl package is installed (it normally is, and
   then nothing is needed):

   ```bash
   rpm -q curl || sudo dnf -y install curl
   ```

2. [user] Save the file list of the installed package:

   ```bash
   rpm -ql curl > /tmp/curl-files.txt
   ```

## Verification

```bash
wc -l /tmp/curl-files.txt
grep /usr/bin/curl /tmp/curl-files.txt
labctl grade packages-03
```

## Explanation

`rpm -ql` queries the local RPM database and prints every path a
package owns, one per line. That is the format the grader compares
with its own `rpm -ql curl`, ignoring order. Redirecting the output
creates the file; no root is needed because `/tmp` is writable and
the database is world-readable.

Use `rpm -ql curl`, not `rpm -qpl`, which needs a package file, and
not `dnf repoquery -l`, which can list files of a different version
than the one installed. On Rocky 9 minimal images `curl-minimal` may be
installed instead; it owns fewer files, which is why the lab installs
`curl` itself.
