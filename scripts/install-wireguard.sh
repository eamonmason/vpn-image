#!/bin/bash

echo "Installing Wireguard"

yum -y update
# sudo apt-get install -y wireguard iptables openresolv
yum -y install wireguard-tools nftables

# Copy keys for Wireguard

echo ${SERVER_PRIVATE_KEY} > /etc/wireguard/privatekey
echo ${SERVER_PUBLIC_KEY} > /etc/wireguard/publickey

# Copy Wireguard config file and replace variables
cd /tmp/provisioning-scripts

cat wg0.conf | sed "s|SERVER_PRIVATE_KEY|${SERVER_PRIVATE_KEY}|" \
| sed "s|CLIENT_PUBLIC_KEY|${CLIENT_PUBLIC_KEY}|" \
> /etc/wireguard/wg0.conf

# Enable traffic to be forwarded through the server

# sed -i /etc/sysctl.d/99-sysctl.conf '/#net.ipv4.ip_forward = 1/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
# sed -i /etc/sysctl.d/99-sysctl.conf '/#net.ipv6.conf.all.forwarding = 1/net.ipv6.conf.all.forwarding = 1/' /etc/sysctl.conf
cat <<EOT >> /etc/sysctl.d/99-sysctl.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOT
sysctl -p

# Start wireguard on boot
systemctl enable wg-quick@wg0

# Uncomment the removal of provisioning scripts when we are sure it is set up correctly

# cd /tmp && rm -rf provisioning-scripts
