#!/bin/bash

################################################################################
#
# The parameters file is meant to be one directory below this one
#
################################################################################

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $CURRENT_DIR/../parameters

################################################################################
#
# Azure command. If this is not set, default to `azure`
# This enables you to use azure whithin docker, for example,
#
# docker run --rm --name azure-cli -ti -v /home/core/_stuff/azure:/root/.azure \
#        -v $(pwd):$(pwd) -w $(pwd) microsoft/azure-cli azure
#
################################################################################

AZURE_CMD=${AZURE_CMD:-azure}

################################################################################
#
# GENERAL
# * RESOURCE GROUP, VNET AND STORAGE ACCOUNT
#
################################################################################

function set_azure_resource_manager()
{
    $AZURE_CMD config mode arm
}

function create_resource_group()
{
    $AZURE_CMD group create "${IFR_PREFIX}" "${IFR_LOCATION}"
}

function create_vnet()
{
    $AZURE_CMD network vnet create \
        --name "${IFR_PREFIX}-vnet" \
        --resource-group "${IFR_PREFIX}" \
        --location "${IFR_LOCATION}" \
        --address-prefixes "${IFR_NETWORK_VNET_CIDR}"
}

function create_storage_account()
{
    $AZURE_CMD storage account create ${IFR_STORAGE_ACC_NAME} \
    --resource-group "${IFR_PREFIX}" \
    --location "${IFR_LOCATION}" \
    --sku-name "LRS" \
    --kind "Storage"
}

################################################################################
#
# SUBNET
#
################################################################################

function create_subnet()
{
    $AZURE_CMD network vnet subnet create \
        --name $1 \
        --resource-group "${IFR_PREFIX}" \
        --vnet-name "${IFR_PREFIX}-vnet" \
        --address-prefix $2
}

################################################################################
#
# Network Security Groups
#
# * Creation of groups
# * Adding of rules
# * Linking of rules
#
################################################################################

function create_network_security_group()
{
    $AZURE_CMD network nsg create \
        --name $1 \
        --resource-group "${IFR_PREFIX}" \
        --location "${IFR_LOCATION}"
}

function add_inbound_rule_to_nsg()
{
    $AZURE_CMD network nsg rule create \
        --name $1 \
        --resource-group "${IFR_PREFIX}" \
        --nsg-name $2 \
        --access "Allow" \
        --protocol "Tcp" \
        --direction "Inbound" \
        --priority $3 \
        --source-address-prefix "Internet" \
        --source-port-range "*" \
        --destination-address-prefix "*" \
        --destination-port-range $4
}

function link_subnet_to_nsg()
{
    $AZURE_CMD network vnet subnet set \
        --name $1 \
        --resource-group "${IFR_PREFIX}" \
        --vnet-name "${IFR_PREFIX}-vnet" \
        --network-security-group-name $2
}

################################################################################
#
# PUBLIC IPs
#
################################################################################

function create_public_ip()
{
    $AZURE_CMD network public-ip create \
        --name $1 \
        --resource-group "${IFR_PREFIX}" \
        --location "${IFR_LOCATION}" \
        --allocation-method "Dynamic" \
        --domain-name-label $2
}

################################################################################
#
# NIC CARDS
#
################################################################################

function create_nic()
{
    if [ -z $4 ]
    then
        PUBLIC_IP_ADDRESS_OPTION=""
    else
        PUBLIC_IP_ADDRESS_OPTION="--public-ip-name $4"
    fi

    $AZURE_CMD network nic create \
        --name $1 \
        --resource-group "${IFR_PREFIX}" \
        --location "${IFR_LOCATION}" \
        --subnet-vnet-name "${IFR_PREFIX}-vnet" \
        --subnet-name $2 \
        --private-ip-address $3 $PUBLIC_IP_ADDRESS_OPTION
}

################################################################################
#
# VIRTUAL MACHINES
#
# * Rendering of templates
# * Azure invocations
#
################################################################################

function render_etcd_template()
{
    sed -e "s/\${IFR_NETWORK_ETCD_PRIV_IP_00}/${IFR_NETWORK_ETCD_PRIV_IP_00}/g" < ${IFR_ETCD_TEMPLATE} > ${IFR_ETCD_TEMPLATE_RENDERED}
}

function render_master_template()
{
    CA_PEM=$(cat $CURRENT_DIR/secrets/k8s/ca.pem | base64 | while read line; do echo -n "$line"; done;)
    APISERVER_PEM=$(cat $CURRENT_DIR/secrets/k8s/apiserver.pem | base64 | while read line; do echo -n "$line"; done;)
    APISERVER_KEY_PEM=$(cat $CURRENT_DIR/secrets/k8s/apiserver-key.pem | base64 | while read line; do echo -n "$line"; done;)

    sed -e "s/\${MASTER_CA_PEM_CONTENTS_BASE64}/$CA_PEM/g" < ${IFR_MASTER_TEMPLATE} > ${IFR_MASTER_TEMPLATE_RENDERED}
    sed -i "s/\${MASTER_APISERVER_PEM_CONTENTS_BASE64}/$APISERVER_PEM/g" ${IFR_MASTER_TEMPLATE_RENDERED}
    sed -i "s/\${MASTER_APISERVER_KEY_PEM_CONTENTS_BASE64}/$APISERVER_KEY_PEM/g" ${IFR_MASTER_TEMPLATE_RENDERED}
    sed -i "s@\${IFR_NETWORK_ETCD_PRIV_IP_00}@${IFR_NETWORK_ETCD_PRIV_IP_00}@g" ${IFR_MASTER_TEMPLATE_RENDERED}
    sed -i "s@\${IFR_NETWORK_SERVICES_CIDR}@${IFR_NETWORK_SERVICES_CIDR}@g" ${IFR_MASTER_TEMPLATE_RENDERED}
    sed -i "s@\${IFR_NETWORK_DNS_SERVICE_IP}@${IFR_NETWORK_DNS_SERVICE_IP}@g" ${IFR_MASTER_TEMPLATE_RENDERED}
    sed -i "s@\${IFR_NETWORK_PODS_CIDR}@${IFR_NETWORK_PODS_CIDR}@g" ${IFR_MASTER_TEMPLATE_RENDERED}
}

function render_worker_template()
{
    CA_PEM=$(cat $CURRENT_DIR/secrets/k8s/ca.pem | base64 | while read line; do echo -n "$line"; done;)
    WORKER_PEM=$(cat $CURRENT_DIR/secrets/k8s/worker.pem | base64 | while read line; do echo -n "$line"; done;)
    WORKER_KEY_PEM=$(cat $CURRENT_DIR/secrets/k8s/worker-key.pem | base64 | while read line; do echo -n "$line"; done;)

    sed -e "s/\${WORKER_CA_PEM_CONTENTS_BASE64}/$CA_PEM/" < ${IFR_WORKER_TEMPLATE} > ${IFR_WORKER_TEMPLATE_RENDERED}
    sed -i "s/\${WORKER_WORKER_PEM_CONTENTS_BASE64}/$WORKER_PEM/" ${IFR_WORKER_TEMPLATE_RENDERED}
    sed -i "s/\${WORKER_WORKER_KEY_PEM_CONTENTS_BASE64}/$WORKER_KEY_PEM/" ${IFR_WORKER_TEMPLATE_RENDERED}
    sed -i "s@\${IFR_NETWORK_ETCD_PRIV_IP_00}@${IFR_NETWORK_ETCD_PRIV_IP_00}@g" ${IFR_WORKER_TEMPLATE_RENDERED}
    sed -i "s/\${IFR_NETWORK_MASTER_PRIV_IP_00}/${IFR_NETWORK_MASTER_PRIV_IP_00}/" ${IFR_WORKER_TEMPLATE_RENDERED}
    sed -i "s/\${IFR_NETWORK_DNS_SERVICE_IP}/${IFR_NETWORK_DNS_SERVICE_IP}/" ${IFR_WORKER_TEMPLATE_RENDERED}
}

function create_vm()
{
    $AZURE_CMD vm create \
        --name $1 \
        --resource-group "${IFR_PREFIX}" \
        --location "${IFR_LOCATION}" \
        --vnet-name "${IFR_PREFIX}-vnet" \
        --vnet-subnet-name $2 \
        --public-ip-domain-name $3 \
        --nic-names $4 \
        --ssh-publickey-file $5 \
        --custom-data $6 \
        --vm-size $7 \
        --storage-account-name ${IFR_STORAGE_ACC_NAME} \
        --os-type "Linux" \
        --admin-username "core" \
        --image-urn "coreos:CoreOS:Beta:1010.1.0"
}
