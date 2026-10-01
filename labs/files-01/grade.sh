#!/bin/bash
# files-01 grader
source /opt/linux-labs/lib/grading.sh

DIR=/tmp/data
FILE=/tmp/data/info.txt

grade_begin files-01

criterion "Directory $DIR exists" test -d "$DIR"
criterion "File $FILE exists" test -f "$FILE"
criterion "File $FILE contains the word hello" grep -qw hello "$FILE"
grade_end
