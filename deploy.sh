#!/bin/bash

set -euf
set -o pipefail

usage() {
    echo
    echo "Usage: deploy.sh <terraform-dir> <terraform-workspace> <ansible-dir>"
    echo
    echo "terraform-dir       - The path to the directory containing the project's Terraform configuration."
    echo "terraform-workspace - The name of the Terraform workspace to use."
    echo "ansible-dir         - The path to the directory containing the project's Ansible configuration."
    echo
}

###################
# Parse Arguments #
###################

if [ -z ${1+x} ]
then
    echo "No Terraform directory specified."
    usage

    exit 1
fi

TF_DIR=$1
shift

if [ -z ${1+x} ]
then
    echo "No Terraform workspace provided."
    usage

    exit 1
fi

# We export this so any Terraform commands will use the appropriate workspace.
export TF_WORKSPACE=$1
shift

if [ -z ${1+x} ]
then
    echo "No Ansible directory specified."
    usage

    exit 1
fi

ANSIBLE_DIR=$1
shift

###########################################
# Provision Infrastructure with Terraform #
###########################################

# Initialize Terraform
echo "Initializing Terraform..."
(cd ${TF_DIR}; terraform init)
echo "Done."
echo

# Build infrastructure
echo "Provisioning Infrastructure..."
echo
(cd ${TF_DIR}; terraform apply -auto-approve)
echo
echo "Done."
echo

echo "Obtaining Terraform outputs..."
TERRAFORM_OUTPUTS=$(cd ${TF_DIR}; terraform output -json)
echo "Done."
echo

echo "Parsing data from Terraform oututs..."
AWS_REGION=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .aws_region.value)
DB_HOST=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .database_host.value)
DB_NAME=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .database_name.value)
DB_PASSWORD=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .database_password.value)
DB_PORT=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .database_port.value)
DB_USER=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .database_user.value)
DJANGO_SECRET_KEY=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .django_secret_key.value)
STATIC_FILES_BUCKET=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .static_files_bucket.value)
WEBSERVER_DOMAIN=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .webserver_domain.value)
echo "Done."
echo

echo "Deployment Parameters:"
echo "    AWS Region: ${AWS_REGION}"
echo "    Database Host: ${DB_HOST}"
echo "    Database Name: ${DB_NAME}"
echo "    Database Password: <sensitive>"
echo "    Database Port: ${DB_PORT}"
echo "    Database User: ${DB_USER}"
echo "    Django Secret Key: <sensitive>"
echo "    Static Files Bucket: ${STATIC_FILES_BUCKET}"
echo "    Webserver Domain: ${WEBSERVER_DOMAIN}"
echo

##############################
# Generate Ansible Inventory #
##############################

# Generate a temporary directory to store files in
tmpdir=$(mktemp -d "${TMPDIR:-/tmp/}$(basename $0).XXXXXXXXXXXX")
inventory_file="${tmpdir}/inventory"

cat > ${inventory_file} <<EOF
[webservers]
${WEBSERVER_DOMAIN}
EOF

echo "Generated inventory file:"
echo
cat ${inventory_file}
echo

#####################################
# Configure Webservers with Ansible #
#####################################

(
    cd ${ANSIBLE_DIR}

    ansible-playbook \
        --inventory ${inventory_file} \
        --extra-vars "aws_region='${AWS_REGION}'" \
        --extra-vars "db_host='${DB_HOST}'" \
        --extra-vars "db_name='${DB_NAME}'" \
        --extra-vars "db_password='${DB_PASSWORD}'" \
        --extra-vars "db_port='${DB_PORT}'" \
        --extra-vars "db_user='${DB_USER}'" \
        --extra-vars "django_secret_key='${DJANGO_SECRET_KEY}'" \
        --extra-vars "static_files_bucket='${STATIC_FILES_BUCKET}'" \
        deploy.yml
)
