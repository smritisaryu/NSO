#!/usr/bin/bash
openrc=$1
tag=$2
key=$3
sshconfig="config"
hostsfile="hosts"
HAproxy1="lb1_HAproxy1_$tag"
HAproxy2="lb2_HAproxy2_$tag"
Bastion="Bastion_$tag"
secgrp="secgrp_$tag"
keypair="keypair_$tag"
source "$openrc"
bastionfip=$(openstack server list --name $Bastion -c Networks -f value | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==2' 2>/dev/null)
haproxyfip=$(openstack server show $HAproxy1 -c addresses | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==1' 2>/dev/null)
haproxyfip2=$(openstack server list --name $HAproxy2 -c Networks -f value | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==1' 2>/dev/null)

####################################################################################################################################################
echo "checking for required nodes"
network="network_$tag"
checknetwork_id=$(openstack network show "$network" -f value -c id 2>/dev/null)
# Define the number of nodes to create
while true; do
    N=$(cat servers.conf)

    if [[ $N =~ ^[0-9]+$ ]]; then
        echo "required servers are : $N"
    else
        echo "The value in server.conf file is not an integer. Please type valid integer"
        break
    fi
    BASE_NAME="node"
    active_servers=$(openstack server list --status ACTIVE | grep 'node[0-9]')
    active_nodes=$(echo "$active_servers" | wc -l)
    echo "we have $active_nodes servers"
    if [ $active_nodes -lt $N ]; then
    # Define the base name for the nodes
        servers_to_add=$((N-active_nodes))
        echo "Servers to be added: $servers_to_add"
        while ((server_to_add > 0)); do
            if [ -f "$hostsfile" ]; then
                rm "$hostsfile"
            fi

            echo "Remove sshconfig file if it exists"
            if [ -f "$sshconfig" ]; then
                rm "$sshconfig"
            fi

            echo "Remove hosts file if it exists"
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
            # loop through the number of nodes
            for ((count = 1; count <= server_to_add; count++)); do
                node_name="node$((active_nodes + count))_$tag"

                # Replace the echo command with the actual command to add a node
                echo "Adding node: $node_name"
                # Example command: openstack server create ...
                openstack server create --image "e6cbd963-8c28-4551-a837-e3b85da5d7a1" --flavor "dd1540cd-4949-46a8-a88e-77ef1cad7988" --key-name "$keypair" --security-group "$secgrp" --nic net-id="$checknetwork_id" "$node_name" 2>/dev/null
                # Add any additional commands or operations related to adding nodes
                
                check_servers_active() {
                    openstack server list -c Status -f value | grep -q "ACTIVE"
                }

                # Loop until all servers are active
                while ! check_servers_active; do
                    echo "Waiting for servers to become active..."
                    sleep 5
                done

                # Get the list of active servers
                #active_servers=$(openstack server list --status ACTIVE -f value -c Name | grep -oP 'node([1-9]+)_'"${tag}")
                #echo "$active_servers"
                # Loop through each active server and extract its IP address
                #for server in $active_servers; do
                ip_address=$(openstack server list --name $node_name -c Networks -f value | grep -Po  '\d+\.\d+\.\d+\.\d+')
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
                #done




            done
            #for ((i=$($count+1); i<=$N; i++)); do
                # Define the node name and tag
             
             #   NODE_NAME="${BASE_NAME}${i}_$2"
              #  NODE_TAG="$tag"

                # Check if the node already exists

               # echo "$(date) Creating node[$i] with $NODE_NAME and tag $NODE_TAG..."
                    # Add your command to create the node here
                #openstack server create --image "e6cbd963-8c28-4551-a837-e3b85da5d7a1" --flavor "dd1540cd-4949-46a8-a88e-77ef1cad7988" --key-name "$keypair" --security-group "$secgrp" --nic net-id="$checknetwork_id" "$NODE_NAME" 2>/dev/null

                    #ssh update
                #echo "$(date) updating ssh config and hosts file"
            #done


            echo "generate hosts file"
            echo "[bastion]" >> $hostsfile
            echo "$Bastion" >> $hostsfile
            echo " " >> $hostsfile
            echo "[HAproxy]" >> $hostsfile
            echo "$HAproxy1" >> $hostsfile
            echo "$HAproxy2" >> $hostsfile

            echo " " >> $hostsfile
            echo "[HAproxy1]" >> $hostsfile
            echo "$HAproxy1" >> $hostsfile
            echo " " >> $hostsfile
            echo "[HAproxy2]" >> $hostsfile
            echo "$HAproxy2" >> $hostsfile
            echo " " >> $hostsfile
            echo "[webservers]" >> $hostsfile

            echo " " >> $hostsfile
            echo "[all:vars]" >> $hostsfile
            echo "ansible_user=ubuntu" >> $hostsfile
            echo "ansible_ssh_private_key_file=~/.ssh/id_rsa" >> $hostsfile
            echo "ansible_ssh_common_args=' -F $sshconfig '" >> $hostsfile
            path=$pwd
            cd ~/.ssh
            touch config
            cd path
            cp -r $sshconfig "~/.ssh/config"
            echo "$(date) Running ansible playbook"
            ansible-playbook -i "$hostsfile" site.yml

        done

    fi
    sleep 30
done
