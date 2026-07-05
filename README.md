# WireGuard Image Creator

Uses `packer` to build a keyless WireGuard AMI.

```sh
packer build .
```

No WireGuard keys are baked into the image. The AMI ships:

- `wireguard-tools` and `nftables`
- `/opt/wireguard/wg0.conf.template` — the server config template (NAT + TCP MSS
  clamping via a single `inet` nftables table)
- `/opt/wireguard/render-wg0.sh` — run by EC2 user-data at boot; fetches keys
  and settings from SSM Parameter Store, renders `/etc/wireguard/wg0.conf` and
  validates it

The renderer reads these parameters from the central region (`eu-west-1` by
default, override with `SSM_REGION`):

| Parameter                           | Type         | Purpose                                                     |
| ----------------------------------- | ------------ | ----------------------------------------------------------- |
| `/vpn-wireguard/SERVER_PRIVATE_KEY` | SecureString | Server WireGuard private key                                |
| `/vpn-wireguard/CLIENT_PEERS`       | String       | One peer per line: `<device-public-key>,<allowed-ip/32>`    |
| `/vpn-wireguard/MTU`                | String       | Tunnel MTU (optional, defaults to 1420)                     |

The `wg-quick@wg0` service is intentionally not enabled in the image; user-data
starts it after rendering succeeds (see the vpn-deploy repo). Because the image
holds no keys, key rotation only requires updating the SSM parameters and
recycling the instance — no AMI rebuild.

Note that the security group should allow port 22 access to where packer is being run.

The packer.yml github action modifies an existing security group rule in the given account and region to allow the action to run packer against it.

The action then creates an AMI with the naming convention, `wireguard-server-YYYY-MM-DD-HHMM` in the target account/region, copies it to all VPN regions and updates `/vpn-wireguard/WIREGUARD_IMAGE` in each.
