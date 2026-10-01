# logging-01: Filtering the systemd journal with journalctl

## Hints

1. All five files come from the same tool, which reads the journal and
   can narrow it down by syslog identifier, priority, order and
   output format. Remember that the output goes to a file in
   ~/journal-lab.
2. See man journalctl for the options that select by identifier and by
   priority. A priority selects that level and everything more severe,
   so one level name is enough for errors.txt and for warnings.txt.
3. Limiting the output to the newest three entries needs an option
   that takes a number. Newest first means the order is reversed; on
   Rocky 8 the reverse option combined with that number picks the
   wrong entries, so reverse the result in another way.
4. For errors.json look at the output formats in the description of
   the -o option. The plain json format prints one entry per line,
   the pretty variant does not.

## Solution

1. [sudo] Save all entries of the identifier labjournal. The
   redirection runs as your user, so the file belongs to you:

   ```bash
   cd ~/journal-lab
   sudo journalctl -t labjournal > all.txt
   ```

2. [sudo] Save the entries of priority err and more severe (crit,
   alert and emerg are included by `-p err`):

   ```bash
   sudo journalctl -t labjournal -p err > errors.txt
   ```

3. [sudo] Save the entries of priority warning and more severe:

   ```bash
   sudo journalctl -t labjournal -p warning > warnings.txt
   ```

4. [sudo] Save the 3 newest entries, newest first:

   ```bash
   sudo journalctl -t labjournal -n 3 -q | tac > latest.txt
   ```

   On Rocky 9, `journalctl -t labjournal -n 3 -r` does the same. On
   Rocky 8 (systemd 239) `-n 3 -r` returns entries that are not the
   newest, so the output is reversed with tac instead; `-q` drops the
   header line.

5. [sudo] Save the err and worse entries as JSON, one object per
   line:

   ```bash
   sudo journalctl -t labjournal -p err -o json > errors.json
   ```

## Verification

```bash
wc -l ~/journal-lab/*.txt
head -n 2 ~/journal-lab/errors.json
labctl grade logging-01
```

## Explanation

`-t` selects by syslog identifier. `-p LEVEL` shows the level and
everything more severe, so `-p err` returns crit and err entries and
`-p warning` adds the warnings. `-n 3` limits the output to the last
three entries and `-r` reverses the order, newest first. `-o json`
prints one JSON object per line; `-o json-pretty` spreads one entry
over many lines and does not meet the task.

The default output of older systemd versions starts with a
`-- Logs begin at ...` line. That line is part of the normal output.

Related options not graded here: `-u UNIT` filters by unit, `-b` by
boot, `-S` and `-U` by time, `-f` follows the journal.
