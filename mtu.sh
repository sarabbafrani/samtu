#!/bin/bash

GREEN='\033[0;32m'

NC='\033[0m'

echo "=========================================="
echo "=                                         ="
echo "=          Welcome to MTU Tester          ="
echo "=             by  SobhanArab              ="
echo -e "=         ${GREEN}http://SobhanArab.com${NC}       ="
echo "=========================================="


# Function to find the default network interface
find_interface() {
    local interface
    interface=$(ip route | grep default | awk '{print $5}')
    echo $interface
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
    local mtu=$1
    local payload=$((mtu - 28 - mux_value))  # Subtract 28 for IP header and MUX value
    local result=$($ping_cmd -M do -s $payload -c $packets_to_send $destination_ip 2>&1)
    local success=$(echo "$result" | grep 'received' | awk -F' ' '{ print $4 }')
    local total=$packets_to_send
    local percentage=$((success * 100 / total))

    if [ $verbose -eq 1 ]; then
        echo "$result"
    fi

    if [ "$percentage" -eq 100 ]; then
        echo "MTU $mtu is OK ($percentage% packets received)"
        return 0
    else
        echo "MTU $mtu is too high ($percentage% packets received)"
        return 1
    fi
}

# Function to display a spinner while waiting for the MTU test
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Parse command line options
verbose=0
while getopts "v" opt; do
    case $opt in
        v) verbose=1 ;;
    esac
done

# Main script
interface=$(find_interface)

if [ -z "$interface" ]; then
    echo "Could not determine the default network interface."
    exit 1
fi

# Prompt the user for a destination IP or domain
read -p "Enter destination IP or domain (press Enter for default 8.8.8.8): " destination_ip

# If the user pressed Enter without typing anything, use the default
if [ -z "$destination_ip" ]; then
    destination_ip="8.8.8.8"
fi

# Check if IPv6
if [[ $destination_ip =~ : ]]; then
    echo "IPv6 address detected. Using ping6 instead of ping."
    ping_cmd="ping6"
else
    ping_cmd="ping"
fi

# Ask the user for the number of packets to send for each MTU test
read -p "Enter the number of packets to send for each MTU test (default is 4): " packets_to_send
packets_to_send=$(validate_number "$packets_to_send" 4)

# Ask the user for the MUX value
read -p "Enter the MUX value (default is 0): " mux_value
mux_value=$(validate_number "$mux_value" 0)

# Set minimum and maximum MTU values
min_mtu=576  # Minimum recommended MTU for IPv4
max_mtu=1500  # Default Ethernet MTU

# Binary search for optimal MTU
low_mtu=$min_mtu
high_mtu=$max_mtu

while [ $low_mtu -le $high_mtu ]; do
    current_mtu=$(( (low_mtu + high_mtu) / 2 ))
    echo "Testing MTU $current_mtu with $packets_to_send packets"
    test_mtu $current_mtu &
    spinner $!
    wait $!

    if test_mtu $current_mtu; then
        low_mtu=$((current_mtu + 1))
    else
        high_mtu=$((current_mtu - 1))
    fi
done

current_mtu=$high_mtu

# Check if the optimal MTU is below the recommended minimum
if [ $current_mtu -lt $min_mtu ]; then
    echo -e "\033[33mWarning: MTU $current_mtu is below the recommended minimum of $min_mtu\033[0m"
    current_mtu=$min_mtu
fi

# Set the optimal MTU
if ! sudo ip link set dev $interface mtu $current_mtu; then
    echo -e "\033[31mFailed to set MTU. Make sure you have sudo privileges.\033[0m"
    exit 1
fi

# Perform one final test with the determined optimal MTU
if test_mtu $current_mtu; then
    echo -e "\033[32mOptimal MTU set to $current_mtu on interface $interface\033[0m"
else
    echo -e "\033[31mOptimal MTU set to $current_mtu on interface $interface (0% packets received)\033[0m"
fi
