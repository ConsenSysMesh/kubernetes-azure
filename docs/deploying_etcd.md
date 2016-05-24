# Deploying ETCD

## Subnetwork

Please check the doc of [Network Topology](network_topology.md) in this
very guide.

## Cloud Config rendering

The `cloud-config` file of this machine is very straightforward

```
#cloud-config

coreos:
  etcd2:
    advertise-client-urls: http://${IFR_NETWORK_ETCD_PRIV_IP_00}:2379
    listen-client-urls: http://0.0.0.0:2379
  units:
    - name: etcd2.service
      command: start
```

A replacement during provisioning adds the private IP we've chosen for this
server.

## Deploy

The entire cluster could be deployed with a single command.

```
./deploy.sh
```

We need, however, to have `azure-cli` installed in our machine. There are two
options to accomplish that:

* [Use the official microsoft guide](https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-install/)
* Use the docker image

In the latter case, this command will be appropiate

```
export AZURE_CMD="docker run --rm --name azure-cli -ti -v /home/johnie/tmp_azure_dir:/root/.azure -v $PWD:$PWD -w $PWD microsoft/azure-cli azure"
```

Where you run it in this very directory to be able to mount the directory
into the container. Notice the dir `/home/johnie/tmp_azure_dir`. We will
need it to persist our azure credentials 

You may wonder why we are using an environmental variable. The script is
configured to seek for this variable, use it if it is defined, or default to
`azure`. The script will fail if it can't find the `azure` program installed
(and you didn't setup `$AZURE_CMD`).

If you want to install just the components of the cluster related to this page,
just follow the item below `Azure CLI script commands` and run the related
commands manually.

## Azure CLI script commands

(TODO)

## Test this component deploy

(TODO)
