// run: 
// cue export builder.tf.cue --out json -o builder.tf.json -t bucket=...
// terrraform apply
//
terraform {
	required_providers {
        aws = {
            source =  "hashicorp/aws"
            version = "~> 3.60"
        }
    }
	required_version = ">= 0.14.9"
}

variable bucket {}
variable region { default = "eu-central-1" }

data  "aws_iam_policy_document" "packer_policy" {
    statement {
        actions = [
            "ec2:AttachVolume", "ec2:AuthorizeSecurityGroupIngress", "ec2:CopyImage", "ec2:CreateImage", "ec2:CreateKeypair", "ec2:CreateSecurityGroup", "ec2:CreateSnapshot", "ec2:CreateTags", "ec2:CreateVolume", "ec2:DeleteKeyPair", "ec2:DeleteSecurityGroup", "ec2:DeleteSnapshot", "ec2:DeleteVolume", "ec2:DeregisterImage", "ec2:DescribeImageAttribute", "ec2:DescribeImages", "ec2:DescribeInstances", "ec2:DescribeInstanceStatus", "ec2:DescribeRegions", "ec2:DescribeSecurityGroups", "ec2:DescribeSnapshots", "ec2:DescribeSubnets", "ec2:DescribeTags", "ec2:DescribeVolumes", "ec2:DetachVolume", "ec2:GetPasswordData", "ec2:ModifyImageAttribute", "ec2:ModifyInstanceAttribute", "ec2:ModifySnapshotAttribute", "ec2:RegisterImage", "ec2:RunInstances",
            "ec2:StopInstances", "ec2:TerminateInstances",
            "ssm:Describe*",
            "ssm:Get*",
            "ssm:List*",
            "s3:Get*",
            "s3:List*"]
        resources = ["*",]
        sid =  "1"
    }
}

data "aws_iam_policy_document" 	"instance-assume-role-policy" {
	statement {
        actions = ["sts:AssumeRole"]
        
        principals {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }   
}


provider "aws" {
  region = var.region
}

resource "aws_ssm_parameter" "packer_artifact_bucket" {
    name =  "artifactdir"
    type =  "String"
    value = var.bucket
}

resource "aws_iam_policy" "packer_policy" {
    name =   "PackerAMIBuilderPolicy"
    path =   "/"
    policy = data.aws_iam_policy_document.packer_policy.json
}

resource "aws_iam_role" "packer_builder_role" {
    name =  "PackerBuilderRole"
    path =  "/system/"
    assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "packer_attachment" {
    role = aws_iam_role.packer_builder_role.name
    policy_arn = aws_iam_policy.packer_policy.arn
}

resource "aws_iam_instance_profile" "packer_profile" {
    name = "PackerBuilderRole"
    role = aws_iam_role.packer_builder_role.name
}