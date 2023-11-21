# WireGuard Image Creator

Uses `packer` to build a WireGuard image.

```sh
packer build --var-file .env.hcl .
```

Create a var file called `.env.hcl`, containing appropriate values for `variables.pkr.hcl`.

Note that the security group should allow port 22 access to where packer is being run.

The packer.yml github action modifies an existing security group rule in the given account and region to allow the action to run packer against it.

The action then creates an AMI with the naming convention, `wireguard-server-YYYY-MM-DD-HHMM` in the target account/region.
