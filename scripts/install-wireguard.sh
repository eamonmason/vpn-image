#!/bin/bash

echo "Installing Wireguard"

yum -y update
yum -y install wireguard-tools nftables

echo ${SERVER_PRIVATE_KEY} > /etc/wireguard/privatekey
echo ${SERVER_PUBLIC_KEY} > /etc/wireguard/publickey

cd /tmp/provisioning-scripts

cat wg0.conf | sed "s|SERVER_PRIVATE_KEY|${SERVER_PRIVATE_KEY}|" \
| sed "s|CLIENT_PUBLIC_KEY|${CLIENT_PUBLIC_KEY}|" \
> /etc/wireguard/wg0.conf

modprobe tcp_bbr || true

cat <<EOT >> /etc/sysctl.d/99-sysctl.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# UDP socket buffers for WireGuard
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144

net.core.netdev_max_backlog = 10000
EOT
sysctl --system

systemctl enable wg-quick@wg0

cd /tmp && rm -rf provisioning-scripts
