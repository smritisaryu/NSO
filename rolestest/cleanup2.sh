#!/bin/bash

openrc="$1"
tag="$2"
network_name="network_$tag"
echo "$(date) clean up $tag resources from $openrc"
floating_ips=$(openstack floating ip list -f value -c ID 2>/dev/null)

if [ -n "$floating_ips" ]; then
    echo "Deleting Floating IPs:"
    for ip in $floating_ips; do
        openstack floating ip delete $ip
    done
else
    echo "No floating IPs exist"
fi

for server_name in $(openstack server list --name "$tag" -f value -c Name 2>/dev/null); do
    echo "Deleting server: $server_name"
    openstack server delete "$server_name"
done


# router check
router_name="router_$tag"
subnet_name="subnet_$tag"
#subnet_id=$(openstack subnet list --name "$subnet_name" -f value -c ID 2>/dev/null)
subnets=$(openstack subnet list --name "$subnet_name" -f value -c ID 2>/dev/null)
if [ -n "$subnets" ]; then
    echo "subnets found"
else
    echo "No subnets found"
fi

subnet_id=$(openstack subnet list --name "subnet_$tag" -c ID -f value)
if [ -n "$subnet_id" ]; then
  for sub in $subnet_id; do
    openstack router remove subnet "$router_name" "$sub"
   # openstack subnet delete "$sub"
  done
 # echo "$(date) Deleted subnet $subnet_name"
else
  echo "$(date) No subnet $subnet_name to remove"
fi

ports=$(openstack port list  -f value -c ID 2>/dev/null)
if [ -n "$ports" ]; then
    echo "Deleting ports:"
    for port_id in $ports; do
        echo "Deleting port: $port_id"
        openstack port delete "$port_id"
    done
else
    echo "No ports found"
fi

subnets=$(openstack subnet list --name "$subnet_name" -f value -c ID 2>/dev/null)
if [ -n "$subnets" ]; then
    echo "Deleting subnets:"
    for subnet_id in $subnets; do
        echo "Deleting subnet: $subnet_id"
        openstack subnet delete "$subnet_id"
    done
else
    echo "No subnets found"
fi

routers=$(openstack router list --column "Name" --format "value" | grep "router_$tag")

count=$(echo "$routers" | wc -l)  # Count the number of routers

if [ "$count" -gt 0 ]; then
    echo "Deleting Routers:"
    for router in $routers; do
        openstack router delete "$router"
    done
else
    echo "No routers exist with the specified tag"
fi

#echo "Deleting router: $router_name"
#openstack router delete "$router_name"


# Check if network exists
network_id=$(openstack network show "$network_name" -f value -c id 2>/dev/null)

if [ -n "$network_id" ]; then
    echo "Network exists with ID: $network_id"
    echo "Deleting network: $network_name"
    openstack network delete "$network_id"
else
    echo "Network $network_name does not exist"
fi


security_groups=$(openstack security group list --column "Name" --format "value" | grep "$tag")

count=$(echo "$security_groups" | wc -l)  # Count the number of security groups

if [ "$count" -gt 0 ]; then
    echo "Deleting Security Groups:"
    for security_group in $security_groups; do
        openstack security group delete "$security_group"
    done
else
    echo "No security groups exist with the specified tag"
fi



# List key pairs with the specified tag
keypairs=$(openstack keypair list -f value -c Name | grep "keypair_$tag")

count=$(echo "$keypairs" | wc -l)  # Count the number of key pairs

if [ "$count" -gt 0 ]; then
    echo "Deleting Key Pairs:"
    for keypair in $keypairs; do
        openstack keypair delete "$keypair"
    done
else
    echo "No key pairs exist with the specified tag"
fi
