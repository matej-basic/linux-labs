#!/bin/bash
# files-01 setup: remove any leftover /tmp/data so the lab starts from
# nothing. Prints nothing on success.
set -eu

rm -rf /tmp/data
