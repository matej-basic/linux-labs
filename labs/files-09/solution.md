# files-09: Hard links, symbolic links and inodes

## Hints

1. A hard link is a second name for an existing inode, a symbolic link
   is a new small file that stores a path. Read man ln: the same
   command creates both, and one option chooses the symbolic kind.
2. The commands stat and readlink show the inode number, the link
   count and the target stored in a symbolic link. The command ls has
   an option that prints inode numbers in front of the names.
3. The command find can match every name of one inode, either by the
   inode number or by naming a reference file. Read man find, tests
   -inum and -samefile.
4. When the name you give ln already exists as a symbolic link to a
   directory, ln follows it and creates the new link inside that
   directory. Read man ln for the options that replace an existing
   name and treat a link to a directory as a normal file.

## Solution

1. [user] Change to the lab directory and create the hard link:

   ```bash
   cd /srv/linklab
   ln data/report.txt backup/report.txt
   stat -c '%i %h %n' data/report.txt backup/report.txt
   ```

2. [user] Create the symbolic link current with a relative target:

   ```bash
   ln -s releases/v2 current
   readlink current
   ```

3. [user] Replace the broken link app.conf:

   ```bash
   ln -sfn /srv/linklab/etc/app.conf app.conf
   readlink app.conf
   cat app.conf
   ```

4. [user] Find every name of the inode of data/shared.dat and save
   the sorted list:

   ```bash
   ls -i data/shared.dat
   find /srv/linklab -samefile /srv/linklab/data/shared.dat \
     | sort > ~/answers/inode-names.txt
   cat ~/answers/inode-names.txt
   ```

5. [user] Remove the name data/old.txt and check the remaining name:

   ```bash
   rm data/old.txt
   stat -c '%i %h %n' archive/2024/old-copy.txt
   cat archive/2024/old-copy.txt
   ```

6. [user] Replace latest with a link to releases/v2:

   ```bash
   ln -sfn releases/v2 latest
   readlink latest
   ls releases/v1
   ```

## Verification

```bash
ls -li /srv/linklab
labctl grade files-09
```

## Explanation

A hard link adds a directory entry for an inode that already exists,
so backup/report.txt and data/report.txt have the same inode number
and the link count rises to 2. Removing one name only lowers the link
count: the data of old.txt stays on disk as long as old-copy.txt
refers to it, and its count drops back to 1.

A symbolic link stores a path as text. A relative target such as
releases/v2 is resolved from the directory that holds the link, so
current works only because it is in /srv/linklab. The target of a
symbolic link does not have to exist, which is how app.conf could be
broken in the first place.

The command find -samefile (or -inum with the number from ls -i)
lists every name of one inode. archive/2024/shared.dat has the same
content but its own inode, and etc/shared.lnk is a symbolic link, so
neither is a name of shared.dat.

Without -n, ln -s releases/v2 latest treats the existing latest as
the directory it points to and creates releases/v1/v2, a link that
does not even resolve. The options -f (replace the name) and -n (do
not follow a link to a directory) replace latest itself. Removing
latest first and then creating it again works as well.
