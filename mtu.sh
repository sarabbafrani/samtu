#!/bin/bash

GREEN='\033[0;32m'

NC='\033[0m'

echo "=========================================="
echo "=                                         ="
echo "=          Welcome to MTU Tester          ="
echo "=             by  SobhanArab              ="
echo -e "=         ${GREEN}http://SobhanArab.com${NC}       ="
echo "=========================================="


# ... [Previous MTU optimization code remains unchanged] ...

echo "MTU optimization complete for all interfaces."

# Part 2: Protocol Performance Optimization

echo "Starting protocol performance optimization..."

# Function to set sysctl parameter
set_sysctl() {
    local param=$1
    local value=$2
    sudo sysctl -w "$param=$value"
    echo "$param = $value" | sudo tee -a /etc/sysctl.conf
}

# Get total system memory in kB
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Calculate 25% of total memory in bytes
mem_quarter=$((total_mem * 1024 / 4))

# TCP settings
echo "Optimizing TCP settings..."
set_sysctl net.ipv4.tcp_rmem "4096 87380 $mem_quarter"
set_sysctl net.ipv4.tcp_wmem "4096 65536 $mem_quarter"
set_sysctl net.core.rmem_max "$mem_quarter"
set_sysctl net.core.wmem_max "$mem_quarter"
set_sysctl net.ipv4.tcp_mem "$mem_quarter $mem_quarter $mem_quarter"
set_sysctl net.ipv4.tcp_fin_timeout 15
set_sysctl net.ipv4.tcp_keepalive_time 1200
set_sysctl net.ipv4.tcp_max_syn_backlog 8192
set_sysctl net.ipv4.tcp_tw_reuse 1

# UDP settings
echo "Optimizing UDP settings..."
set_sysctl net.ipv4.udp_mem "$mem_quarter $mem_quarter $mem_quarter"
set_sysctl net.ipv4.udp_rmem_min 8192
set_sysctl net.ipv4.udp_wmem_min 8192

# General network settings
echo "Optimizing general network settings..."
set_sysctl net.core.netdev_max_backlog 16384
set_sysctl net.core.somaxconn 8192
set_sysctl net.ipv4.ip_local_port_range "1024 65535"

# Congestion control
echo "Setting congestion control algorithm to BBR..."
set_sysctl net.core.default_qdisc fq
set_sysctl net.ipv4.tcp_congestion_control bbr

# Increase the maximum number of open file descriptors
echo "Increasing maximum number of open file descriptors..."
sudo ulimit -n 1048576
echo "* soft nofile 1048576" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 1048576" | sudo tee -a /etc/security/limits.conf

# Optimize kernel parameters for high-performance networking
echo "Optimizing kernel parameters for high-performance networking..."
set_sysctl net.core.optmem_max 65535
set_sysctl net.ipv4.tcp_slow_start_after_idle 0
set_sysctl net.ipv4.tcp_mtu_probing 1
set_sysctl net.ipv4.tcp_fastopen 3

# Apply all changes
echo "Applying all changes..."
sudo sysctl -p

echo "Protocol performance optimization complete."
echo "Please reboot your system for all changes to take effect."
