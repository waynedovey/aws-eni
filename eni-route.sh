#!/bin/bash

#function log { logger -t "vpc" -- $1; }

#function die {
#	[ -n "$1" ] && log "$1"
#	log "Configuration of HA NAT failed!"
#	exit 1
#}

yum install NetworkManager-config-routing-rules -y
systemctl enable NetworkManager-dispatcher.service
systemctl start NetworkManager-dispatcher.service

#dhclient

ETH0_MAC=$(cat /sys/class/net/eth0/address) ||
    die "Unable to determine MAC address on eth0."
echo "Found MAC ${ETH0_MAC} for eth0."

ETH1_MAC=$(cat /sys/class/net/eth1/address) ||
    die "Unable to determine MAC address on eth1."
echo "Found MAC ${ETH1_MAC} for eth1."

URI_ETH0="http://169.254.169.254/latest/meta-data/network/interfaces/macs/${ETH0_MAC}/subnet-ipv4-cidr-block"
echo "Metadata location for ipv4 range: ${URI_ETH0}"

RANGE_ETH0=$(curl --retry 3 --silent --fail ${URI_ETH0})
if [ $? -ne 0 ]; then
   echo "Unable to retrive VPC CIDR range from meta-data, using 0.0.0.0/0 instead. PAT may be insecure!"
   RANGE_ETH0="0.0.0.0/0"
else
   echo "Retrieved VPC CIDR range ${RANGE_ETH0} from meta-data."
fi

URI_ETH0_IP="http://169.254.169.254/latest/meta-data/network/interfaces/macs/${ETH0_MAC}/local-ipv4s"
echo "Metadata location for ipv4 add: ${URI_ETH0_IP}"

ETH0_IP=$(curl --retry 3 --silent --fail ${URI_ETH0_IP})
if [ $? -ne 0 ]; then
   echo "Unable to retrive VPC IP from meta-data, using null instead"
   ETH0_IP=""
else
   echo "Retrieved VPC IP ${ETH0_IP} from meta-data."
fi

URI_ETH1="http://169.254.169.254/latest/meta-data/network/interfaces/macs/${ETH1_MAC}/subnet-ipv4-cidr-block"
echo "Metadata location for ipv4 range: ${URI_ETH1}"

RANGE_ETH1=$(curl --retry 3 --silent --fail ${URI_ETH1})
if [ $? -ne 0 ]; then
   echo "Unable to retrive VPC CIDR range from meta-data, using 0.0.0.0/0 instead. PAT may be insecure!"
   RANGE_ETH1="0.0.0.0/0"
else
   echo "Retrieved VPC CIDR range ${RANGE_ETH1} from meta-data."
fi

URI_ETH1_IP="http://169.254.169.254/latest/meta-data/network/interfaces/macs/${ETH1_MAC}/local-ipv4s"
echo "Metadata location for ipv4 add: ${URI_ETH1_IP}"

ETH1_IP=$(curl --retry 3 --silent --fail ${URI_ETH1_IP})
if [ $? -ne 0 ]; then
   echo "Unable to retrive VPC IP from meta-data, using null instead"
   ETH1_IP=""
else
   echo "Retrieved VPC IP ${ETH1_IP} from meta-data."
fi

ip route add ${RANGE_ETH0} dev eth0 tab 1
ip route add ${RANGE_ETH1} dev eth1 tab 2

ETH0_ROUTE=$(read _ _ gateway _ < <(ip route list match 0/0); echo "$gateway")
ETH1_ROUTE=$(read _ _ gateway _ < <(ip route list match 0/0); echo "$gateway")

ip route add default via ${ETH0_ROUTE} dev eth0 tab 1
ip route add default via ${ETH1_ROUTE} dev eth1 tab 2

ip rule add from ${ETH0_IP}/32 tab 1 priority 100
ip rule add from ${ETH1_IP}/32 tab 2 priority 200
ip route flush cache 

echo "${RANGE_ETH0} dev eth0 tab 1" > /etc/sysconfig/network-scripts/route-eth0
echo "default via ${ETH0_ROUTE} dev eth0 tab 1" >> /etc/sysconfig/network-scripts/route-eth0

echo "${RANGE_ETH1} dev eth1 tab 2" > /etc/sysconfig/network-scripts/route-eth1
echo "default via ${ETH1_ROUTE} dev eth1 tab 2" >> /etc/sysconfig/network-scripts/route-eth1

echo "from ${ETH0_IP}/32 tab 1 priority 100" > /etc/sysconfig/network-scripts/rule-eth0
echo "from ${ETH1_IP}/32 tab 2 priority 200" > /etc/sysconfig/network-scripts/rule-eth1
