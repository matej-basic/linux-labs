# Files 01 Solution

Commands to reach the expected state:

```bash
# Create directory and file
mkdir -p /tmp/data

echo "hello" > /tmp/data/info.txt
```

Verify:
```bash
ls -l /tmp/data
cat /tmp/data/info.txt
sudo labctl grade files-01
```
