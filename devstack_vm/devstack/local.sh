#!/bin/bash
set -e

source /home/ubuntu/devstack/functions
source /home/ubuntu/devstack/functions-common

echo "Before updating nova flavors:"
nova flavor-list

nova flavor-create m1.nano 42 128 1 1

nova flavor-create m1.micro 84 128 2 1

nova flavor-create m1.heat 451 512 5 1

echo "After updating nova flavors:"
nova flavor-list

# Add DNS config to the private network
subnet_id=`neutron subnet-show private-subnet | grep ' id ' | awk '{print $4}'`
neutron subnet-update $subnet_id --dns_nameservers list=true 8.8.8.8 8.8.4.4

echo "Neutron networks:"
neutron net-list
for net in `neutron net-list -F name | grep -v '\-\-' | grep -v "name" | awk {'print $2'}`; do neutron net-show $net;done
echo "Neutron subnetworks:"
neutron subnet-list
for subnet in `neutron subnet-list -F name | grep -v '\-\-' | grep -v "name" | awk {'print $2'}`; do neutron subnet-show $subnet; done

