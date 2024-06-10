#!/bin/bash

GREEN='\033[0;32m'

NC='\033[0m'

echo "=========================================="
echo "=                                         ="
echo "=          Welcome to MTU Tester          ="
echo "=             by  SobhanArab              ="
echo -e "=         ${GREEN}http://SobhanArab.com${NC}       ="
echo "=========================================="
# Function to find the active network interface
find_interface() {
    local interface
    interface=$(ip route | grep default | awk '{print $5}')
    echo $interface
}

# Function to test MTU with ping and display success percentage
test_mtu() {
    local mtu=$1
    local payload=$((mtu - 28 - $mux_value))  # Subtract 28 for IP header and MUX value
    local result=$(ping -M do -s $payload -c $packets_to_send $destination_ip 2>&1)
    local success=$(echo "$result" | grep 'received' | awk -F' ' '{ print $4 }')
    local total=$packets_to_send
    local percentage=$((success * 100 / total))

    if [ $percentage -eq 100 ]; then
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
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Main script
interface=$(find_interface)

# Prompt the user for a destination IP or domain
read -p "Enter destination IP or domain (press Enter for default 8.8.8.8): " destination_ip

# If the user pressed Enter without typing anything, use the default
if [ -z "$destination_ip" ]; then
    destination_ip="8.8.8.8"
fi

# Ask the user for the number of packets to send for each MTU test
read -p "Enter the number of packets to send for each MTU test (default is 4): " packets_to_send
packets_to_send=${packets_to_send:-4}

# Ask the user for the MUX value
read -p "Enter the MUX value (default is 0): " mux_value
mux_value=${mux_value:-0}

# Start with a high MTU value (default Ethernet MTU is 1500)
current_mtu=1500

# Main loop to find the optimal MTU
while true; do
    echo "Testing MTU $current_mtu with $packets_to_send packets"
    # Start the spinner
    spinner $$ &
    spinner_pid=$!
    # Run the MTU test
    if test_mtu $current_mtu; then
        # If the current MTU is OK, try a higher one
        ((current_mtu += 10))
    else
        # If the current MTU is too high, try a lower one
        ((current_mtu -= 10))
    fi
    # Kill the spinner
    kill $spinner_pid

    # Check if the current MTU has 100% packet success
    if test_mtu $current_mtu; then
        break
    fi
done

# Set the optimal MTU
sudo ip link set dev $interface mtu $current_mtu
# Perform one final test with the determined optimal MTU
if test_mtu $current_mtu; then
    echo -e "\033[32mOptimal MTU set to $current_mtu on interface $interface \033[0m"
else
    echo -e "\033[31mOptimal MTU set to $current_mtu on interface $interface (0% packets received)\033[0m"
fi

# Optionally, make the MTU setting persistent
# Uncomment the following lines if you want to make the change persistent
# Note: The method for persistence depends on your network configuration
# For netplan (common in newer Debian versions)
# echo "Setting MTU in netplan configuration"
# sudo tee /etc/netplan/mtu.yaml <<EOF
# network:
#   version: 2
#   renderer: networkd
#   ethernets:
#     $interface:
#       mtu: $current_mtu
# EOF
# sudo netplan apply

# For ifupdown (older Debian versions)
# echo "Setting MTU in ifupdown configuration"
# sudo tee /etc/network/interfaces.d/$interface.cfg <<EOF
# iface $interface inet manual
#     mtu $current_mtu
# EOF
# sudo ifdown $interface && sudo ifup -a
