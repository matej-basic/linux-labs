#!/bin/bash

# Reset lab state
rm -rf /tmp/data

# Print task description
cat <<'EOF'

====================================================
LAB: Files and Directories (files-01)
====================================================

OBJECTIVE:
Create the required directory and file so that
the system matches the expected final state.

REQUIREMENTS:
- Create a directory: /tmp/data
- Create a file: /tmp/data/info.txt
- The file must contain the word: hello

NOTES:
- You may use any valid Linux commands
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade files-01

====================================================

EOF

