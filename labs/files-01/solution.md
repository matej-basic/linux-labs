# files-01: Directories and files

## Solution

1. [user] Create the directory:

   ```bash
   mkdir -p /tmp/data
   ```

2. [user] Create the file with the word hello in it:

   ```bash
   echo "hello" > /tmp/data/info.txt
   ```

## Verification

```bash
ls -l /tmp/data
cat /tmp/data/info.txt
labctl grade files-01
```

## Explanation

`mkdir` creates the directory and the redirection `>` creates the file
and writes the text into it. The grader checks the final state only:
the directory, a regular file and the word hello in it. The word is
matched as a whole word, so text such as "othello" does not count.
