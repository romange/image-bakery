#!/bin/bash

set -e

CONFIG=/home/dev/.aws/config
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

cat <<EOT > $CONFIG
[default]
region = $REGION
EOT
cp $CONFIG /root/.aws/
chown dev:dev $CONFIG

aws ssm get-parameters --names github-access --query "Parameters[*].{Value:Value}" \
--output text > /home/dev/.ssh/git_id_key
chmod 600 /home/dev/.ssh/git_id_key
chown dev:dev /home/dev/.ssh/git_id_key

cat <<EOT >> /home/dev/.ssh/config
Host github.com
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/git_id_key
EOT

