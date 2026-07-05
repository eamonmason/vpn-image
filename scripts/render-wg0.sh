#!/bin/bash
# Renders /etc/wireguard/wg0.conf from SSM parameters at instance boot.
#
# Required parameters (in ${SSM_REGION}, default eu-west-1):
#   /vpn-wireguard/SERVER_PRIVATE_KEY  (SecureString) server WireGuard private key
#   /vpn-wireguard/CLIENT_PEERS        (String)       one peer per line: <public-key>,<allowed-ip/32>
# Optional:
#   /vpn-wireguard/MTU                 (String)       tunnel MTU, defaults to 1420
set -euo pipefail

SSM_REGION="${SSM_REGION:-eu-west-1}"
PARAM_PREFIX="/vpn-wireguard"
TEMPLATE="/opt/wireguard/wg0.conf.template"
CONF="/etc/wireguard/wg0.conf"
DEFAULT_MTU=1420

get_param() {
  aws ssm get-parameter --name "${PARAM_PREFIX}/$1" --with-decryption \
    --region "${SSM_REGION}" --query Parameter.Value --output text
}

# Instance-profile credentials can lag instance start, so retry required lookups.
get_required_param() {
  local name="$1" attempt
  for attempt in 1 2 3 4 5; do
    if get_param "${name}"; then
      return 0
    fi
    echo "Attempt ${attempt} to fetch ${PARAM_PREFIX}/${name} failed, retrying" >&2
    sleep $((attempt * 2))
  done
  echo "Unable to fetch ${PARAM_PREFIX}/${name} from SSM in ${SSM_REGION}" >&2
  return 1
}

server_private_key=$(get_required_param SERVER_PRIVATE_KEY)
client_peers=$(get_required_param CLIENT_PEERS)
mtu=$(get_param MTU 2>/dev/null) || mtu="${DEFAULT_MTU}"

umask 077
{
  sed -e "s|__SERVER_PRIVATE_KEY__|${server_private_key}|" \
      -e "s|__MTU__|${mtu}|" "${TEMPLATE}"
  while IFS=, read -r public_key allowed_ip; do
    public_key="${public_key//[[:space:]]/}"
    allowed_ip="${allowed_ip//[[:space:]]/}"
    [ -n "${public_key}" ] || continue
    printf '\n[Peer]\nPublicKey = %s\nAllowedIPs = %s\n' "${public_key}" "${allowed_ip}"
  done <<< "${client_peers}"
} > "${CONF}"
chmod 600 "${CONF}"

# Validate the rendered config parses before wg-quick is started against it.
wg-quick strip wg0 > /dev/null
echo "Rendered ${CONF} (MTU ${mtu})"
