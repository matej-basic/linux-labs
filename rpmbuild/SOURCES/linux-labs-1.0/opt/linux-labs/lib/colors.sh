#!/bin/bash
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

pass() { echo -e "${GREEN}PASS${RESET}: $1"; }
fail() { echo -e "${RED}NO PASS${RESET}: $1"; }

