##########################
Pre Requisits
##########################

1. Access Key for AWS and store it as secret in jenkins
2. Cluster domain name Suffix: .k8s.local


# Update repositories
sudo apt update && sudo apt full-upgrade -y

# Download and install KOPS
curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x ./kops
sudo mv ./kops /usr/local/bin/

# download and install kubectl
curl -Lo kubectl https://dl.k8s.io/release/$(curl -s -L https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Install unzip
sudo apt install unzip

# Download and install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version


# configure the aws client to use your new IAM user
##########################
### Update variables ##### Currently not working
##########################
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile user2 && aws configure set aws_secret_access_key "$AWS_ACCESS_KEY_SECRET" --profile user2 && aws configure set region "$AWS_REGION" --profile user2 && aws configure set output "text" --profile user2
aws iam list-users

# Because "aws configure" doesn't export these vars for kops to use, we export them now
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
export NAME=shlomishalitkopstest.k8s.local
export KOPS_STATE_STORE=s3://${KOPS_STATE_BUCKET_NAME}
export CONTROL_PLANE_COUINT=1
export NODE_COUNT=2
export ZONE=eu-west-1a
export NODE_SIZE=t3.xlarge
export KOPS_STATE_BUCKET_NAME=shlomishalit-kopstest-state-store
export KOPS_OIDC_BUCKET_NAME=shlomishalit-kopstest-oidc-store

# Create S3 bucket
aws s3api create-bucket --bucket ${KOPS_STATE_BUCKET_NAME} --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1


# Enable acls
aws s3api create-bucket \
    --bucket ${KOPS_OIDC_BUCKET_NAME} \
    --region eu-west-1 \
    --object-ownership BucketOwnerPreferred --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-public-access-block \
    --bucket ${KOPS_OIDC_BUCKET_NAME} \
    --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false  
aws s3api put-bucket-acl \
    --bucket ${KOPS_OIDC_BUCKET_NAME} \
    --acl public-read 


### Update variable
# enable bucket versioning
aws s3api put-bucket-versioning --bucket ${KOPS_STATE_BUCKET_NAME}  --versioning-configuration Status=Enabled

# Enable Bucket encryption
aws s3api put-bucket-encryption --bucket ${KOPS_STATE_BUCKET_NAME} --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'


# Get list of availablility zones
aws ec2 describe-availability-zones --region eu-west-1


# Create the cluster

# Create cluster configuration
kops create cluster \
    --name=${NAME} \
    --cloud=aws \
    --zones=${ZONE} \
	--control-plane-count ${CONTROL_PLANE_COUINT} \
	--node-count ${NODE_COUNT} \
	--node-size ${NODE_SIZE} \
    --discovery-store=s3://${KOPS_OIDC_BUCKET_NAME}/${NAME}/discovery \
	--state s3://${KOPS_STATE_BUCKET_NAME}


# Build the cluster
kops update cluster --name ${NAME} --state s3://${KOPS_STATE_BUCKET_NAME} --yes --admin

# Validate cluster
kops validate cluster --name ${NAME} --wait 10m --state s3://${KOPS_STATE_BUCKET_NAME}

###### delete the cluster #######
kops edit cluster --name ${NAME} --state s3://${KOPS_STATE_BUCKET_NAME}
kops delete cluster --name ${NAME} --state s3://${KOPS_STATE_BUCKET_NAME} --yes

# Scale In Cluster
kops get ig

kops edit ig nodes
kops edit ig master-us-west-2a

kops update cluster --yes
kops rolling-update cluster
