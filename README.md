# image-bakery
Cloud image bakery

Packer build requires the appropriate policies/service-accounts to be setup in each of the clouds.

`tf/` folder has requires scripts in order to setup those policies.

To import existing resources you can use:
`terraform import --var bucket=.... aws_iam_instance_profile.packer_profile PackerBuilderRole`

## Provision for clouds

GCP setup:

```bash
cd tf/gcp/
terraform init
terraform apply --var "bucket=..." --var "project=..." --var "region=..."
```


AWS setup:

Update the state (gcs) bucket inside main.tf and then:

```bash

cd tf/aws/
terraform init
terraform apply --var "bucket=..." --var "region=..."

```

## Packer build

### GCP
`./build.sh --gcp --var-file=myvars.pkrvars.hcl`

to copy image to another project:
`gcloud compute --project=project2 images create image-2 --family=newfamily --source-image-family=srcfamily --source-image-project=project`

### AWS

`./build.sh --aws  --var-file=myvars.pkrvars.hcl`

or

`./build.sh --azure  --var-file=myvars.pkrvars.hcl`
