#!/bin/bash
# Test script for static node IP functionality

echo "=========================================="
echo "Testing Static Node IP Configuration"
echo "=========================================="
echo ""

# Source the helper library
source /root/linux-labs/src/opt/linux-labs/lib/load-config.sh

echo "Test 1: Auto-calculated IPs (default)"
echo "--------------------------------------"
export LAB_NETWORK="192.168.100.0/24"
export NODE_COUNT=3
export NODE_IPS=""
load_lab_config

echo "NODE_IPS is empty: ${NODE_IPS:-<empty>}"
echo "NODE_COUNT: $NODE_COUNT"
echo "Node 1 IP: $(get_node_ip 1)"
echo "Node 2 IP: $(get_node_ip 2)"
echo "Node 3 IP: $(get_node_ip 3)"
echo "All node IPs: $(get_all_node_ips)"
echo ""

echo "Test 2: Static IPs"
echo "-------------------"
export LAB_NETWORK="192.168.100.0/24"
export NODE_COUNT=3
export NODE_IPS="10.0.0.101 10.0.0.102 10.0.0.103"
load_lab_config

echo "NODE_IPS is set: $NODE_IPS"
echo "NODE_COUNT: $NODE_COUNT"
echo "Node 1 IP: $(get_node_ip 1)"
echo "Node 2 IP: $(get_node_ip 2)"
echo "Node 3 IP: $(get_node_ip 3)"
echo "All node IPs: $(get_all_node_ips)"
echo ""

echo "Test 3: Static IPs with different subnets"
echo "------------------------------------------"
export LAB_NETWORK="192.168.100.0/24"
export NODE_COUNT=4
export NODE_IPS="172.16.0.10 172.16.0.20 192.168.50.5 10.0.0.100"
load_lab_config

echo "NODE_IPS is set: $NODE_IPS"
echo "NODE_COUNT: $NODE_COUNT"
echo "Node 1 IP: $(get_node_ip 1)"
echo "Node 2 IP: $(get_node_ip 2)"
echo "Node 3 IP: $(get_node_ip 3)"
echo "Node 4 IP: $(get_node_ip 4)"
echo "All node IPs: $(get_all_node_ips)"
echo ""

echo "Test 4: Edge case - Empty NODE_IPS with different network"
echo "----------------------------------------------------------"
export LAB_NETWORK="10.10.10.0/24"
export NODE_COUNT=2
export NODE_IPS=""
load_lab_config

echo "NODE_IPS is empty: ${NODE_IPS:-<empty>}"
echo "NODE_COUNT: $NODE_COUNT"
echo "Node 1 IP: $(get_node_ip 1)"
echo "Node 2 IP: $(get_node_ip 2)"
echo "All node IPs: $(get_all_node_ips)"
echo ""

echo "=========================================="
echo "All tests completed!"
echo "=========================================="
