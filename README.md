# WireGuard Image Creator

Uses `packer` to build a WireGuard image.

```sh
packer build --var-file .env.hcl .
```

Create a var file called `.env.hcl`, containing appropriate values for `variables.pkr.hcl`.

Note that the security group should allow port 22 access to where packer is being run.
