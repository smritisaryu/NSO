#!/usr/bin/bash

openrc=$1
tag=$2
key=$3
sshconfig="config"
hostsfile="hosts"
sudo apt-get update 2>/dev/null
echo "updated"
source "$openrc"
sudo apt-get install jq -y 2>/dev/null
echo "installed requirements"

echo "$(date) Check if network exists"
network="network_$tag"
# Check if network exists
checknetwork_id=$(openstack network show "$network" -f value -c id 2>/dev/null)

if [ -n "$checknetwork_id" ]; then
    echo "$(date) Network exists with ID: $checknetwork_id"
else
    echo "$(date) Network does not exist"
    #create
    net_create=$(openstack network create "$network" --tag "$TAG" 2>/dev/null)
    echo "$(date) Network created"
fi
checknetwork_id=$(openstack network show "$network" -f value -c id 2>/dev/null)

echo "$(date) Check if subnet exists"
subnet="subnet_$tag"
# Check if network exists
check_subnet_id=$(openstack subnet show "$subnet" -f value -c id 2>/dev/null)

if [ -n "$check_subnet_id" ]; then
    echo "$(date) subnet exists with ID: $check_subnet_id"
else
    echo "$(date) subnet does not exist"
    #create sub
  #  openstack subnet create --network "$network" --dhcp --ip-version 4 --subnet-range 10.10.0.0/24 --allocation-pool start= 10.10.0.2, end=10.10.0.30 "$subnet"

    sub_create=$(openstack subnet create --network "$network" --dhcp --ip-version 4 --subnet-range 10.10.0.0/24 --allocation-pool start=10.10.0.2,end=10.10.0.10 "$subnet" 2>/dev/null)
    echo "$(date) subnet created"
fi

echo "$(date) Check if router exists"
router="router_$tag"
# Check if router exists
router_id=$(openstack router show "$router" -f value -c id 2>/dev/null)

if [ -n "$router_id" ]; then
    echo "$(date) Router exists with ID: $router_id"
else
    echo "$(date) Router does not exist"
    router_create=$(openstack router create --external-gateway ext-net "$router" 2>/dev/null)
    echo "$(date) router created"
fi

echo "$(date) checking if router is added to the router"
#add router to subnet
router_interfaces=$(openstack router show "$router" -f json 2>/dev/null)
#interface is connected here
if echo "$(date) $router_interfaces" | jq -r '.interfaces_info[].subnet_id' | grep -q "$check_subnet_id"; then
    echo "$(date) Subnet is already added to the router"
else
    echo "$(date) Subnet is not added to the router"
    router_add=$(openstack router add subnet $router $subnet)
    echo "$(date) subnet added to the router"
fi

echo "$(date) Check if security group exists"
secgrp="secgrp_$tag"
secgrp_id=$(openstack security group show "$secgrp" -f value -c id 2>/dev/null)
if [ -n "$secgrp_id" ]; then
    echo "$(date) security group exists with ID: $secgrp_id"
else
    echo "$(date) security group does not exist"
    sec_group=$(openstack security group create "$secgrp" --tag "$tag" 2>/dev/null)
    r1=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 22 --protocol tcp --ingress $secgrp 2>/dev/null)
    r2=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 22 --protocol tcp --egress $secgrp 2>/dev/null)
    r3=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 80 --protocol icmp --ingress $secgrp 2>/dev/null)
    r4=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 5000 --protocol tcp --ingress $secgrp 2>/dev/null)
    r5=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 8080 --protocol tcp --ingress $secgrp 2>/dev/null)
    r6=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 6000 --protocol udp --ingress $secgrp 2>/dev/null)
    r7=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 9090 --protocol tcp --ingress $secgrp 2>/dev/null)
    r8=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 9100 --protocol tcp --ingress $secgrp 2>/dev/null)
    r9=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 3000 --protocol tcp --ingress $secgrp 2>/dev/null)
    r10=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 161 --protocol udp --ingress $secgrp 2>/dev/null)
    echo "$(date) security group created"

fi

echo "$(date) Check if keypair exists"
keypair="keypair_$tag"
existing_keypairs=$(openstack keypair list -f json)
#create keypair
if echo "$(date) $existing_keypairs" | jq -r '.[].Name' | grep -q "$keypair"; then
    echo "$(date) Keypair already exists"
else
    keypair_create=$(openstack keypair create --public-key "$key" "$keypair" 2>/dev/null)
    echo "$(date) Keypair created"
fi


echo "$(date) Check if HAproxy1 exists"
HAproxy1="lb1_HAproxy1_$tag"
check_ha1=$(openstack server show "$HAproxy1" -f value -c id 2>/dev/null)

if [ -n "$check_ha1" ]; then
    echo "----- $(date) HAproxy1 server exists with ID: $check_ha1 -----"
else
    echo "----- $(date) HAproxy1 does not exist -----"
    # Create
    ha1_create=$(openstack server create --image "Ubuntu 20.04 Focal Fossa 20200423" --flavor "1C-2GB-50GB" --key-name "$keypair" --security-group "$secgrp" --nic net-id="$checknetwork_id" "$HAproxy1" 2>/dev/null)
    echo "-----$(date) Master HAproxy created -----"
fi

echo "$(date) Check if HAproxy2 exists"
HAproxy2="lb2_HAproxy2_$tag"
check_ha2=$(openstack server show "$HAproxy2" -f value -c id )

if [ -n "$check_ha2" ]; then
    echo "----- $(date) HAproxy2 server exists with ID: $check_ha2 -----"
else
    echo "----- $(date) HAproxy2 does not exist -----"
    # Create
    ha2_create=$(openstack server create --image "Ubuntu 20.04 Focal Fossa 20200423" --flavor "1C-2GB-50GB" --key-name "$keypair" --security-group "$secgrp" --nic net-id="$checknetwork_id" "$HAproxy2" 2>/dev/null)
    echo "-----$(date) Backup HAproxy created -----"
fi

echo "$(date) Check if Bastion exists"
Bastion="Bastion_$tag"
check_bastion=$(openstack server show "$Bastion" -f value -c id)

if [ -n "$check_bastion" ]; then
    echo "----- $(date) Bastion server exists with ID: $check_ha1 -----"
else
    echo "----- $(date) Bastion does not exist -----"
    # Create
    bastion=$(openstack server create --image "Ubuntu 20.04 Focal Fossa 20200423" --flavor "1C-2GB-50GB" --key-name "$keypair" --security-group "$secgrp" --nic net-id="$checknetwork_id" "$Bastion" 2>/dev/null)
    echo "----- $(date) Bastion created -----"
fi

#############################################################
echo "creating nodes"
# Define the number of nodes to create
N=3

# Define the base name for the nodes
BASE_NAME="node"

# Loop through the number of nodes
for ((i=1; i<=N; i++)); do
    # Define the node name and tag
    NODE_NAME="${BASE_NAME}${i}_$2"
    NODE_TAG="$tag"

    # Check if the node already exists
    if openstack server show "$NODE_NAME" >/dev/null 2>&1; then
        echo "$(date) Node $NODE_NAME already exists."
    else
        echo "$(date) Creating node $NODE_NAME with tag $NODE_TAG..."
        # Add your command to create the node here
        nodes_create=$(openstack server create --image "Ubuntu 20.04 Focal Fossa 20200423" --flavor "1C-2GB-50GB" --key-name "$keypair" --security-group "$secgrp" --nic net-id="$checknetwork_id" "$NODE_NAME" 2>/dev/null)
    fi
done

##############################################################
echo "$(date) checking for unassigned floating ips"
floating_unassigned=$(openstack floating ip list --status ACTIVE --port "" -f value -c "ID")
for floating_ip in $floating_unassigned; do
    delete = $(openstack floating ip delete "$floating_ip" 2>/dev/null)
done

# Wait for servers to become active
echo "$(date) Waiting for servers to become active"
while true; do
    HAproxy1_status=$(openstack server show "$HAproxy1" -f value -c status 2>/dev/null)
    HAproxy2_status=$(openstack server show "$HAproxy2" -f value -c status 2>/dev/null)
    Bastion_status=$(openstack server show "$Bastion" -f value -c status 2>/dev/null)
    # Check if all servers are active
    if [ "$HAproxy1_status" = "ACTIVE" ] && [ "$HAproxy2_status" = "ACTIVE" ] && [ "$Bastion_status" = "ACTIVE" ]; then
        break
    fi
    sleep 10
done

floating_ip3=$(openstack floating ip create ext-net -f value -c floating_ip_address 2>/dev/null)
#openstack server add floating ip "$HAproxy1" "$floating_ip1"
#openstack server add floating ip "$HAproxy2" "$floating_ip2"
openstack server add floating ip "$Bastion" "$floating_ip3" 2>/dev/null

echo "$(date) Floating IPs assigned successfully: $floating_ip3 to $Bastion"

#################################################################################################################################
echo "$(date) Creating port"
vip_port="vip_$tag"
vip=$(openstack port create --network "$network" --fixed-ip subnet="$subnet" --no-security-group "$vip_port" 2>/dev/null)
fip2=$(openstack floating ip create ext-net -f value -c floating_ip_address 2>/dev/null)
echo "Attatching floating ip to vip port"
add_vip_fip=$(openstack floating ip set --port "$vip_port" $fip2 2>/dev/null)

if [ -f "vip" ]; then
    rm "vip"
fi

vip_addr=$(openstack port show "$vip_port" -f value -c fixed_ips | grep -Po '\d+\.\d+\.\d+\.\d+' 2>/dev/null)
echo "$vip_addr" >> vip

echo "$(date) updating port...."
update_port=$(openstack port set --allowed-address ip-address="$fip2" "$vip_port" 2>/dev/null)


bastionfip=$(openstack server list --name $Bastion -c Networks -f value | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==2' 2>/dev/null)
haproxyfip=$(openstack server show $HAproxy1 -c addresses | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==1' 2>/dev/null)
haproxyfip2=$(openstack server list --name $HAproxy2 -c Networks -f value | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==1' 2>/dev/null)

echo "updating ports of haproxy servers"
portid_ha1=$(openstack port list --fixed-ip ip-address="$haproxyfip" -c ID -f value 2>/dev/null)
portid_ha2=$(openstack port list --fixed-ip ip-address="$haproxyfip2" -c ID -f value 2>/dev/null)

update_port1=$(openstack port set --allowed-address ip-address="$vip_addr" "$portid_ha1" 2>/dev/null)
update_port2=$(openstack port set --allowed-address ip-address="$vip_addr" "$portid_ha2" 2>/dev/null)


echo "$(date) creating ssh config and hosts file"
# Remove hosts file if it exists
if [ -f "$hostsfile" ]; then
    rm "$hostsfile"
fi

# Remove sshconfig file if it exists
if [ -f "$sshconfig" ]; then
    rm "$sshconfig"
fi
echo "updating ssh config file"
echo " " >> $sshconfig
echo "Host $Bastion" >> $sshconfig
echo "   User ubuntu" >> $sshconfig
echo "   HostName $bastionfip" >> $sshconfig
echo "   IdentityFile ~/.ssh/id_rsa" >> $sshconfig
echo "   UserKnownHostsFile /dev/null" >> $sshconfig
echo "   StrictHostKeyChecking no" >> $sshconfig
echo "   PasswordAuthentication no" >> $sshconfig

echo " " >> $sshconfig
echo "Host $HAproxy1" >> $sshconfig
echo "   User ubuntu" >> $sshconfig
echo "   HostName $haproxyfip" >> $sshconfig
echo "   IdentityFile ~/.ssh/id_rsa" >> $sshconfig
echo "   StrictHostKeyChecking no" >> $sshconfig
echo "   PasswordAuthentication no ">> $sshconfig
echo "   ProxyJump $Bastion" >> $sshconfig

echo " " >> $sshconfig
echo "Host $HAproxy2" >> $sshconfig
echo "   User ubuntu" >> $sshconfig
echo "   HostName $haproxyfip2" >> $sshconfig
echo "   IdentityFile ~/.ssh/id_rsa" >> $sshconfig
echo "   StrictHostKeyChecking no" >> $sshconfig
echo "   PasswordAuthentication no ">> $sshconfig
echo "   ProxyJump $Bastion" >> $sshconfig

echo "generate hosts file"
echo "[bastion]" >> $hostsfile
echo "$Bastion" >> $hostsfile
echo " " >> $hostsfile
echo "[HAproxy]" >> $hostsfile
echo "$HAproxy1" >> $hostsfile
echo "$HAproxy2" >> $hostsfile

echo " " >> $hostsfile
echo "[webservers]" >> $hostsfile

# Get the list of active servers
active_servers=$(openstack server list --status ACTIVE -f value -c Name | grep -oP 'node([1-9]+)_'"${tag}")
#echo "$active_servers"
# Loop through each active server and extract its IP address
for server in $active_servers; do
        ip_address=$(openstack server list --name $server -c Networks -f value | grep -Po  '\d+\.\d+\.\d+\.\d+')
        echo " " >> $sshconfig
        echo "Host $server" >> $sshconfig
        echo "   User ubuntu" >> $sshconfig
        echo "   HostName $ip_address" >> $sshconfig
        echo "   IdentityFile ~/.ssh/id_rsa" >> $sshconfig
        echo "   UserKnownHostsFile=/dev/null" >> $sshconfig
        echo "   StrictHostKeyChecking no" >> $sshconfig
        echo "   PasswordAuthentication no" >> $sshconfig
        echo "   ProxyJump $Bastion" >> $sshconfig

        echo "$server" >> $hostsfile
done

echo " " >> $hostsfile
echo "[HAproxy1]" >> $hostsfile
echo "$HAproxy1" >> $hostsfile
echo " " >> $hostsfile
echo "[HAproxy2]" >> $hostsfile
echo "$HAproxy2" >> $hostsfile

echo " " >> $hostsfile
echo "[all:vars]" >> $hostsfile
echo "ansible_user=ubuntu" >> $hostsfile
echo "ansible_ssh_private_key_file=~/.ssh/id_rsa" >> $hostsfile
echo "ansible_ssh_common_args=' -F $sshconfig '" >> $hostsfile
echo "SSH config file and hosts file generated"
cp -r config "~/.ssh/config"
echo "$(date) Running ansible playbook"
ansible-playbook -i "$hostsfile" site.yml

echo " bastion ip address:  "$bastionfip" "
echo " vip address: "$fip2" "
