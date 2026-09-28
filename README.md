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

Packer creates a temporary security group that allows SSH only from the public
IP of wherever it is run (`temporary_security_group_source_public_ip`), and
deletes it after the build.

## CI (GitHub Actions)

On every push to `main`, the `packer.yml` workflow builds an AMI named
`wireguard-server-YYYY-MM-DD-HHMM` in `eu-west-1`, copies it to all VPN regions
and updates `/vpn-wireguard/WIREGUARD_IMAGE` in each.

### AWS authentication (GitHub OIDC)

The workflow stores no AWS keys. It exchanges a GitHub OIDC token for
short-lived credentials on the `vpn-image-packer` role, defined in
[`iam/github-oidc-role.yaml`](iam/github-oidc-role.yaml). The role trusts only
pushes to `main` in this repository, and can only run the EC2 actions Packer
and the AMI copies need (in the workflow's regions) and write
`/vpn-wireguard/WIREGUARD_IMAGE`.

One-time setup:

1. Confirm the account's GitHub OIDC provider exists (it is shared with other
   repos, so the stack reuses it rather than creating it):

   ```sh
   aws iam get-open-id-connect-provider --open-id-connect-provider-arn \
     "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
   ```

   `ClientIDList` must include `sts.amazonaws.com`. If the provider is missing,
   create it with `aws iam create-open-id-connect-provider --url
   https://token.actions.githubusercontent.com --client-id-list
   sts.amazonaws.com`.

2. Deploy the role:

   ```sh
   aws cloudformation deploy \
     --template-file iam/github-oidc-role.yaml \
     --stack-name vpn-image-github-oidc \
     --capabilities CAPABILITY_NAMED_IAM \
     --region eu-west-1
   ```

3. Set the role ARN as a repository **variable** (not a secret):

   ```sh
   gh variable set AWS_ROLE_ARN -R eamonmason/vpn-image --body "$(aws cloudformation describe-stacks \
     --stack-name vpn-image-github-oidc --region eu-west-1 \
     --query "Stacks[0].Outputs[?OutputKey=='RoleArn'].OutputValue" --output text)"
   ```

4. After a `main` run succeeds with the role, delete the old
   `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` repository secrets and
   deactivate and delete the IAM user access keys they held.
