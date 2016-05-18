# Network Topology

In this section we are going to discuss the minimum network topology involved
in our azure cluster

## Network Topology Diagram

![network-topology-diagram](https://cloud.githubusercontent.com/assets/729830/15291038/7721ceac-1b52-11e6-95ce-52545b7b779b.png)

## Networks

We will be needing to define 5 networks: 3 of them are _physical_, as we are
adding servers IP with these networks, and 2 of them _virtual_, generated
by flannels using a virtual network overlay.

### Physical Subnets

* `10.42.0.0/24`: ETCD Subnet
* `10.42.1.0/24`: Master Subnet
* `10.42.2.0/24`: Worker Subnet

### Virtual Subnets

* `10.42.16.0/20`: Kubernetes Services Subnet
* `10.42.128.0/17`: Kubernetes Pods Subnet

## Private IP Addresses

There is a number of Private IPs we need to define, as we are going to render
these values during the provision of the machines.

* `10.42.0.4`: ETCD Server
* `10.42.1.4`: Master Server
* `10.42.2.4`: Worker Server
* `10.42.16.1`: Kubernetes Service
* `10.42.16.10`: DNS Service

Please note that for the _physical_ nodes, our first IP starts at `4`. This is
due to the fact that Azure reserves the first three IPs on each subnet.

For convention, Kubernetes Service is the first IP of the services network.

## FQDN (Fully Qualified Domain Name)

We are using to access master a fully qualified domain name, which is derived
from the resource group we areusing (by convention) and the domain name of
azure. You can, however, use your own domain name.
