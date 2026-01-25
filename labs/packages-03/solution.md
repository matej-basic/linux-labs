# Packages 03 Solution

Install curl and save file list:

```bash
# Ensure curl is installed
sudo dnf install -y curl

# Save list of files installed by curl to /tmp/curl-files.txt
rpm -ql curl > /tmp/curl-files.txt

# Verify the file was created
cat /tmp/curl-files.txt

# Count files
wc -l /tmp/curl-files.txt

# Search for specific file
grep /usr/bin/curl /tmp/curl-files.txt
```

Grade:
```bash
sudo labctl grade packages-03
```
