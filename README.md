# MTU Tester

This repository contains a Bash script for testing and setting the optimal MTU (Maximum Transmission Unit) size for network interfaces. The script automates the process of finding the highest MTU value that can be used without packet loss.

## Features

- Automatically tests MTU values to find the optimal size.
- Supports custom destination IP or domain.
- Allows setting the number of packets to send for each MTU test.
- Option to specify a MUX value.
- Colorized output for easy readability.
- Spinner animation during MTU tests for visual feedback.

## Usage

To use the script, simply download it and run it on your server. Here's a one-liner command to download and execute the script using `curl`:

```bash
curl -sSL https://raw.githubusercontent.com/sarabbafrani/samtu/main/mtu.sh > mtu.sh && chmod +x mtu.sh && sudo ./mtu.sh
```

```bash
wget -qO- https://raw.githubusercontent.com/sarabbafrani/samtu/main/mtu.sh > mtu.sh && chmod +x mtu.sh && sudo ./mtu.sh
```
