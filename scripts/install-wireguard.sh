#!/bin/bash

echo "Installing Wireguard"

yum -y update
# sudo apt-get install -y wireguard iptables openresolv
yum -y install wireguard-tools nftables iproute-tc

# Copy keys for Wireguard

echo ${SERVER_PRIVATE_KEY} > /etc/wireguard/privatekey
echo ${SERVER_PUBLIC_KEY} > /etc/wireguard/publickey

# Copy Wireguard config file and replace variables
cd /tmp/provisioning-scripts

cat wg0.conf | sed "s|SERVER_PRIVATE_KEY|${SERVER_PRIVATE_KEY}|" \
| sed "s|CLIENT_PUBLIC_KEY|${CLIENT_PUBLIC_KEY}|" \
> /etc/wireguard/wg0.conf

# Ensure BBR module is loaded
modprobe tcp_bbr || true

# Enable traffic to be forwarded through the server and optimize TCP/UDP for long-distance streaming
cat <<EOT >> /etc/sysctl.d/99-sysctl.conf
# Enable IP forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# BBR Congestion Control (Google BBR is extremely resilient to high latency / packet loss)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Buffer tuning for high Bandwidth-Delay Product (BDP) transoceanic connections
# Allows up to 16MB TCP window sizes (3rd value) to fully utilize bandwidth over 300ms RTT
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# UDP Buffer tuning (avoids dropping WireGuard packets under bursty high-speed video traffic)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144

# Increase network queue size
net.core.netdev_max_backlog = 10000
EOT
sysctl --system

# Start wireguard on boot
systemctl enable wg-quick@wg0

# Uncomment the removal of provisioning scripts when we are sure it is set up correctly

# cd /tmp && rm -rf provisioning-scripts
