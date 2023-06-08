#!/bin/bash

set -eu pipefail

start_time=$(date +%s)
date1=$(date +"%s")

# yc
if ! command -v yc &> /dev/null ; then 
  echo "Installing yc CLI"
  curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
fi
  YC="${HOME}/yandex-cloud/bin/yc"

if ! ${YC} compute instance list &> /dev/null ; then 
  ${YC} init
fi

# Terraform
if ! command -v terraform &> /dev/null ; then 
  echo "Installing Terraform from th MCS mirror"
  wget -nv https://hashicorp-releases.mcs.mail.ru/terraform/1.4.6/terraform_1.4.6_linux_amd64.zip
  unzip terraform_1.4.6_linux_amd64.zip
  sudo ln terraform /usr/bin
fi
TF_IN_AUTOMATION=1 terraform init -upgrade
export TF_VAR_yc_token=$(${YC} config get token)
export TF_VAR_yc_cloud_id=$(${YC} config get cloud-id)
export TF_VAR_yc_folder_id=$(${YC} config get folder-id)
TF_IN_AUTOMATION=1 terraform apply -auto-approve

# Ansible
if ! command -v pip &> /dev/null ; then 
  echo "Installing pip"
  sudo apt install python3-pip
fi
if ! command -v ansible &> /dev/null ; then 
  echo "Installing ansible"
  pip install ansible
fi
export ANSIBLE_HOST_KEY_CHECKING=False
ansible -become -i inventory.yml  -a "wget -nv https://mirror.yandex.ru/mirrors/elastic/7/pool/main/e/elasticsearch/elasticsearch-7.17.9-amd64.deb" elasticsearch_cluster
ansible -become -i inventory.yml  -a "dpkg -i elasticsearch-7.17.9-amd64.deb" elasticsearch_cluster
ansible -become -i inventory.yml  -a "systemctl start elasticsearch" elasticsearch_cluster
ansible -become -i inventory.yml  -a "systemctl status elasticsearch" elasticsearch_cluster
ansible -become -i inventory.yml  -a "curl -s localhost:9200" elasticsearch_cluster

end_time=$(date +%s)
date2=$(date +"%s")
echo "###############"
echo "Execution time was $(( end_time - start_time )) s."
DIFF=$(( date2 - date1 ))
echo "Duration: $(( DIFF / 3600 )) hours $((( DIFF % 3600) / 60 )) minutes $(( DIFF % 60 )) seconds"
echo "###############"
