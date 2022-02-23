CONFIG=/home/dev/.aws/config
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
cat <<EOT
[default]
region = $REGION
EOT

aws ssm get-parameters --names github-access --query "Parameters[*].{Value:Value}" \
--output text > /home/dev/.ssh/git_id_key
chmod 600 /home/dev/.ssh/git_id_key

cat <<EOT >> /home/dev/.ssh/config
Host github.com
    IdentityFile ~/.ssh/git_id_key
EOT

