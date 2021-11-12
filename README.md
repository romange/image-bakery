# image-bakery
Cloud image bakery

Packer build requires the appropriate policies/service-accounts to be setup in each of the clouds.

`tf/` folder has requires scripts in order to setup those policies.
## Provision for clouds

GCP setup:

```bash
cd tf/gcp/
terraform init
terraform apply --var "bucket=..." --var "project=..." --var "region=..."
```


AWS setup:

```bash

cd tf/aws/
terraform init
terraform apply --var "bucket=..." --var "region=..."

```

## Packer build

`packer build  --only=googlecompute.dev  --var-file=myvars.pkrvars.hcl  dev.pkr.hcl`

or

`packer build  --only=amazon-ebs.dev  --var-file=myvars.pkrvars.hcl  dev.pkr.hcl`

