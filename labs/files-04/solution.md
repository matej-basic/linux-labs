# files-04: Brace expansion and file organisation

## Solution

1. [user] Change to the lab directory and create the 108 files with
   brace expansion:

   ```bash
   cd /srv/archive
   touch {report,memo,chart}_{sep,oct,nov,dec}_{a,b,c}{1,2,3}
   ```

2. [user] Create the 3 x 4 directory tree:

   ```bash
   mkdir -p {report,memo,chart}/{sep,oct,nov,dec}
   ```

3. [user] Move the files by name:

   ```bash
   for t in report memo chart; do
     for m in sep oct nov dec; do
       mv ${t}_${m}_* $t/$m/
     done
   done
   ```

## Verification

```bash
ls /srv/archive
ls /srv/archive/report/sep
find /srv/archive -type f | wc -l
labctl grade files-04
```

## Explanation

Each glob such as `report_sep_*` matches exactly the nine files of one
type and month, so twelve `mv` calls move all 108 files. `mkdir -p`
with two brace lists creates the three type directories and their four
month directories in one command.

All commands run as your normal user, so you own every file and
directory you create. Files created as root or with sudo belong to root
and fail the ownership criterion.
