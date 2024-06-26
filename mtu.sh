#!/bin/bash

GREEN='\033[0;32m'

NC='\033[0m'

echo "=========================================="
echo "=                                         ="
echo "=          Welcome to MTU Tester          ="
echo "=             by  SobhanArab              ="
echo -e "=         ${GREEN}http://SobhanArab.com${NC}       ="
echo "=========================================="


# Function to find all active network interfaces
find_interfaces() {
    ip -o link show up | awk -F': ' '{print $2}' | cut -d@ -f1 | grep -v 'lo'
}

# Function to validate numeric input
validate_number() {
    local input=$1
    local default=$2
    if [[ $input =~ ^[0-9]+$ ]]; then
        echo $input
    else
        echo $default
    fi
}

# Function to test MTU with ping and display success percentage
test_mtu() {
    local interface=$1
    local mtu=$2
    local payload=$((mtu - 28 - mux_value))  # Subtract 28 for IP header and MUX value
    $ping_cmd -I $interface -M do -s $payload -c $packets_to_send $destination_ip >/dev/null 2>&1
    return $?
}

# Function to update network configuration
update_network_config() {
    local interface=$1
    local mtu=$2

    if command -v netplan &>/dev/null; then
        sudo sed -i "/\s*$interface:/,/^\s*[^[:space:]]/s/mtu:.*/mtu: $mtu/" /etc/netplan/01-netcfg.yaml
    elif [ -f "/etc/network/interfaces" ]; then
        sudo sed -i "/iface $interface/,/^$/s/mtu .*/mtu $mtu/" /etc/network/interfaces
    elif [ -d "/etc/sysconfig/network-scripts" ]; then
        sudo sed -i "s/^MTU=.*/MTU=$mtu/" "/etc/sysconfig/network-scripts/ifcfg-$interface"
    fi
    sudo ip link set dev "$interface" mtu "$mtu"
}

# Parse command line options
verbose=0
while getopts "v" opt; do
    case $opt in
        v) verbose=1 ;;
    esac
done

# Main script
interfaces=$(find_interfaces)

if [ -z "$interfaces" ]; then
    echo "No active network interfaces found."
    exit 1
fi

read -p "Enter destination IP or domain (press Enter for default 8.8.8.8): " destination_ip
destination_ip=${destination_ip:-8.8.8.8}

if [[ $destination_ip =~ : ]]; then
    ping_cmd="ping6"
else
    ping_cmd="ping"
fi

read -p "Enter the number of packets to send for each MTU test (default is 2): " packets_to_send
packets_to_send=$(validate_number "$packets_to_send" 2)

read -p "Enter the MUX value (default is 0): " mux_value
mux_value=$(validate_number "$mux_value" 0)

min_mtu=576
max_mtu=9000

for interface in $interfaces; do
    echo "Optimizing MTU for interface $interface"
    low_mtu=$min_mtu
    high_mtu=$max_mtu
    
    while [ $low_mtu -le $high_mtu ]; do
        current_mtu=$(( (low_mtu + high_mtu) / 2 ))
        if [ $verbose -eq 1 ]; then
            echo "Testing MTU $current_mtu on $interface"
        fi
        
        if test_mtu $interface $current_mtu; then
            low_mtu=$((current_mtu + 1))
        else
            high_mtu=$((current_mtu - 1))
        fi
    done

    optimal_mtu=$high_mtu
    
    if [ $optimal_mtu -lt $min_mtu ]; then
        echo -e "\033[33mWarning: MTU $optimal_mtu is below the recommended minimum of $min_mtu for $interface\033[0m"
        optimal_mtu=$min_mtu
    fi

    echo "Setting optimal MTU to $optimal_mtu on interface $interface"
    update_network_config "$interface" "$optimal_mtu"

    if test_mtu $interface $optimal_mtu; then
        echo -e "\033[32mOptimal MTU set to $optimal_mtu on interface $interface\033[0m"
    else
        echo -e "\033[31mFailed to set optimal MTU to $optimal_mtu on interface $interface\033[0m"
    fi
done

if command -v netplan &>/dev/null; then
    sudo netplan apply
fi

echo "MTU optimization complete for all interfaces."
