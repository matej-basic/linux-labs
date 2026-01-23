#!/bin/bash

# Remove test rules and restore default firewall state

# Print that we are cleaning up the lab
echo "Cleaning up firewall-01 lab..."

# Remove HTTP service if added
firewall-cmd --remove-service=http --zone=public >/dev/null 2>&1

# Remove custom port if added
firewall-cmd --remove-port=8080/tcp --zone=public >/dev/null 2>&1

# Remove any permanent rules as well
firewall-cmd --remove-service=http --zone=public --permanent >/dev/null 2>&1
firewall-cmd --remove-port=8080/tcp --zone=public --permanent >/dev/null 2>&1

# Reload firewall configuration
firewall-cmd --reload >/dev/null 2>&1

