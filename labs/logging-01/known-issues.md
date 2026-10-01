# logging-01: known issues

- 2026-10-02 | rocky8 | workaround | journalctl 239 returns entries that
  are not the newest when the reverse option is combined with a line
  count. The solution reverses the output of a plain line count
  instead. Rocky 9 handles the combination correctly.
- 2026-10-02 | rocky8 | workaround | The JSON output of journalctl 239
  puts spaces around the colon of each field. The grader accepts both
  spellings.
