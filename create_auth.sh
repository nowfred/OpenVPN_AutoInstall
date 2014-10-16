#!/bin/bash

CA=/etc/openvpn/easy-rsa/keys/ca.crt
CLIENT_CRT=/etc/openvpn/easy-rsa/keys/client.crt
CLIENT_KEY=/etc/openvpn/easy-rsa/keys/client.key
IP=`ifconfig eth0 | grep inet | awk '{print $2}' | sed 's/addr://'`

echo client
echo dev tun
echo proto udp
echo remote $IP 1194
echo resolv-retry infinite
echo nobind
echo persist-key
echo persist-tun
echo comp-lzo
echo verb 3
echo "<ca>"
cat $CA
echo "</ca>"
echo "<cert>"
cat $CLIENT_CRT
echo "</cert>"
echo "<key>"
cat $CLIENT_KEY
echo "</key>"