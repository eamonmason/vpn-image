#!/bin/bash

echo "Installing Wireguard"

yum -y update
yum -y install wireguard-tools nftables

# No keys are baked into the AMI. EC2 user-data runs render-wg0.sh at boot to
# fetch keys from SSM, render /etc/wireguard/wg0.conf and start wg-quick@wg0,
# so the service is deliberately not enabled here.
mkdir -p /opt/wireguard
cd /tmp/provisioning-scripts
install -m 644 wg0.conf.template /opt/wireguard/wg0.conf.template
install -m 755 render-wg0.sh /opt/wireguard/render-wg0.sh

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

cd /tmp && rm -rf provisioning-scripts
