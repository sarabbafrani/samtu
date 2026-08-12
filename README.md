# samtu

Finds the largest packet that survives the path to a host, by binary search with `ping -M do`, and optionally sets that MTU on the interface.

Useful when a tunnel or a PPPoE link silently drops large packets: pages half load, SSH hangs on long lines, downloads stall at random. That is a path MTU problem, and this tells you the number to use.

[فارسی](README.fa.md)

## Usage

```sh
git clone https://github.com/sarabbafrani/samtu.git
cd samtu
chmod +x mtu.sh
./mtu.sh
```

```
destination 8.8.8.8 over eth0, current MTU 1500, 4 packets per probe

  ok      1038
  dropped 1269
  ok      1153
  ...

largest working MTU: 1420
run again with -a to set it, or: sudo ip link set dev eth0 mtu 1420
```

Nothing is changed until you pass `-a`.

## Options

```
-d HOST   destination, address or name (default 8.8.8.8)
-i IFACE  interface to read the ceiling from and to change
-c N      packets per probe (default 4)
-o N      tunnel overhead to subtract, in bytes
-w N      timeout per probe in seconds (default 2)
-l N      lowest size to consider (default 576, or 1280 for IPv6)
-a        set the discovered MTU on the interface
-q        print only the number, for use in scripts
```

```sh
./mtu.sh -q
1420

./mtu.sh -d example.com -o 80 -a
```

IPv6 destinations are detected from the address and use `ping -6` with the 48 byte header, instead of the deprecated `ping6` binary.

## How it searches

The upper bound is the current MTU of the interface, not a hardcoded 1500, so jumbo frames and tunnels are both handled. Each probe sends `size - 28 - overhead` bytes with the don't fragment bit set, and a size counts as working only when every packet comes back. The search is a binary search, so a 1500 byte range costs about ten probes rather than hundreds.

Before searching it checks that the lowest size gets through at all, so a host that ignores ICMP fails with a clear message instead of reporting an MTU of zero.

## Requirements

`ping` from iputils and `ip` from iproute2. Setting the MTU needs root, and the script only asks for it when you use `-a`.

## License

MIT
