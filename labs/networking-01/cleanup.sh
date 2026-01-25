#!/bin/bash
# Networking Lab 01: Cleanup

nmcli connection delete labnet-static &>/dev/null || true

echo "Cleanup complete."
