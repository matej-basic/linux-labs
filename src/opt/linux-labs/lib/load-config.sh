#!/bin/bash
# Lab Configuration Loader
# This script loads lab configuration from the system or user config file
# Source this in lab scripts with: source /opt/linux-labs/lib/load-config.sh

# Configuration file locations
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linux-labs"
CONFIG_FILE="$CONFIG_DIR/config"
SYSTEM_CONFIG="/etc/linux-labs/config"

# Use system config if available, otherwise user config
if [[ -f "$SYSTEM_CONFIG" ]]; then
    CONFIG_FILE="$SYSTEM_CONFIG"
fi

# Load configuration with defaults
load_lab_config() {
    # Save any pre-existing environment variables (they have highest priority)
    local env_lab_network="$LAB_NETWORK"
    local env_lab_gateway="$LAB_GATEWAY"
    local env_lab_dns="$LAB_DNS"
    local env_nodes_enabled="$NODES_ENABLED"
    local env_node_count="$NODE_COUNT"
    local env_node_ips="$NODE_IPS"
    local env_ssh_key_path="$SSH_KEY_PATH"
    local env_ssh_user="$SSH_USER"
    local env_ssh_port="$SSH_PORT"
    local env_docker_enabled="$DOCKER_ENABLED"
    
    # Load from config file if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
    
    # Priority order: Environment > Config file > Defaults
    # Restore environment variables if they were set
    LAB_NETWORK="${env_lab_network:-${LAB_NETWORK:-172.25.250.0/24}}"
    LAB_GATEWAY="${env_lab_gateway:-${LAB_GATEWAY:-172.25.250.254}}"
    LAB_DNS="${env_lab_dns:-${LAB_DNS:-8.8.8.8}}"
    NODES_ENABLED="${env_nodes_enabled:-${NODES_ENABLED:-false}}"
    NODE_COUNT="${env_node_count:-${NODE_COUNT:-1}}"
    NODE_IPS="${env_node_ips:-${NODE_IPS:-}}"
    SSH_KEY_PATH="${env_ssh_key_path:-${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}}"
    SSH_USER="${env_ssh_user:-${SSH_USER:-root}}"
    SSH_PORT="${env_ssh_port:-${SSH_PORT:-22}}"
    DOCKER_ENABLED="${env_docker_enabled:-${DOCKER_ENABLED:-false}}"
    
    # Export all variables so they're available to child processes
    export LAB_NETWORK
    export LAB_GATEWAY
    export LAB_DNS
    export NODES_ENABLED
    export NODE_COUNT
    export SSH_KEY_PATH
    export SSH_USER
    export SSH_PORT
    export DOCKER_ENABLED
    export NODE_IPS
}

# Get a specific node IP based on configuration
get_node_ip() {
    local node_num="$1"
    
    # If static IPs are configured, use them
    if [[ -n "$NODE_IPS" ]]; then
        echo "$NODE_IPS" | awk -v n="$node_num" '{print $n}'
        return
    fi
    
    # Otherwise calculate from LAB_NETWORK
    local base_ip=$(echo "$LAB_NETWORK" | cut -d'/' -f1 | sed 's/\.[0-9]*$//')
    local node_offset=$((node_num + 9))
    echo "${base_ip}.${node_offset}"
}

# Get all node IPs as a space-separated list
get_all_node_ips() {
    # If static IPs are configured, return them directly
    if [[ -n "$NODE_IPS" ]]; then
        echo "$NODE_IPS" | xargs
        return
    fi
    
    # Otherwise calculate from LAB_NETWORK
    local ips=""
    for ((i=1; i<=NODE_COUNT; i++)); do
        ips="$ips $(get_node_ip $i)"
    done
    echo "$ips" | xargs
}

# Test connectivity to a remote node (requires SSH)
test_node_connectivity() {
    local node_ip="$1"
    timeout 5 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
        -i "$SSH_KEY_PATH" \
        -p "$SSH_PORT" \
        "$SSH_USER@$node_ip" "echo OK" 2>/dev/null
}

# Execute a command on a remote node via SSH
run_on_node() {
    local node_ip="$1"
    shift
    local cmd="$@"
    
    ssh -o StrictHostKeyChecking=no \
        -i "$SSH_KEY_PATH" \
        -p "$SSH_PORT" \
        "$SSH_USER@$node_ip" "$cmd"
}

# Wait for a node to be SSH-accessible (with timeout)
wait_for_node() {
    local node_ip="$1"
    local max_attempts="${2:-30}"
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if test_node_connectivity "$node_ip" >/dev/null 2>&1; then
            return 0
        fi
        ((attempt++))
        sleep 1
    done
    
    return 1
}

# Color output functions for grading scripts
# ANSI color codes for pass/fail output
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

pass() {
    printf "${COLOR_GREEN}PASS${COLOR_RESET}: %s\n" "$*"
}

fail() {
    printf "${COLOR_RED}FAIL${COLOR_RESET}: %s\n" "$*"
}

# Load configuration on import
load_lab_config
