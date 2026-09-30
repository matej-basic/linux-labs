# Files 04 Solution

Commands to reach the expected state, run as your normal user (not root):

```bash
cd /srv/archive

# Create the 108 files
touch {report,memo,chart}_{sep,oct,nov,dec}_{a,b,c}{1,2,3}

# Create the 3 x 4 directory tree
mkdir -p {report,memo,chart}/{sep,oct,nov,dec}

# Move the files by name
for t in report memo chart; do
  for m in sep oct nov dec; do
    mv ${t}_${m}_* $t/$m/
  done
done
```

Each glob such as `report_sep_*` matches exactly the nine files of one
type and month, so twelve `mv` calls move everything. Use `man mv` and
`mkdir --help` if an option is unclear.

Verify:
```bash
ls /srv/archive
ls report/sep
find /srv/archive -type f | wc -l
sudo labctl grade files-04
```
