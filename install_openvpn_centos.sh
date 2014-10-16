#Run script as root or exit

[ `id -u` -ne 0 ] && echo Please run script as root...exiting && exit 1

(

#Roll back installation
roll_back() {
echo
echo ---------Rolling back changes...-----------
if [ `rpm -qa | grep -i openvpn` ]; then
        yum erase -y openvpn
        rm -fr /etc/openvpn
fi

[ `rpm -qa | grep -i easy-rsa` ] && yum erase -y easy-rsa
[ /opt/epel-release* ] && rm -f /opt/epel*

echo Please check log for errors
exit

}

line_error() {
echo There was an error at line $1, please check log
exit
}

#trap signals
trap roll_back SIGHUP SIGINT SIGTERM
trap 'line_error $LINENO' ERR

cd /opt 

echo Installing wget
yum install wget -y

echo Installing epel repo
yum repolist | grep -i epel  || wget http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm

#Install EPEL REpo
rpm -Uvh epel-release-6-8.noarch.rpm && echo  Installation completed

if [ $? -ne 0 ]; then
        echo Problem retrieving EPEL repo... Please install manually.
        roll_back
fi

echo Installing EASY-RSA
yum install easy-rsa -y # since openvpn does not ship with that anymore

#Install openVPN and copy server configuration after that
echo Installing OpenVPN
yum install openvpn -y && echo Installation completed

echo copying config files...
cp /usr/share/doc/openvpn*/sample*/sample-config-files/server.conf /etc/openvpn

if [ $? -ne 0 ]; then
        echo Problem with installation
        roll_back
fi

echo Edit config file /etc/openvpn/server.conf
# Updating the line about 2048bit vs 1024bit key
 perl -p -i -e "s/dh dh1024.pem/dh dh2048.pem/i"  /etc/openvpn/server.conf  || echo dh dh2048.pem >> /etc/openvpn/server.conf

 perl -p -i -e "s/;push \"redirect/push \"redirect/i"  /etc/openvpn/server.conf  || echo push '"redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf

#Uncomment the lines for traffic routing
 perl -p -i -e "s/;push \"redirect/push \"redirect/i"  /etc/openvpn/server.conf  || echo push '"redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf

#And the DNS settings#
 perl -p -i -e "s/;push \"dhcp-option.*/push \"dhcp-option DNS 8.8.8.8\"/i"  /etc/openvpn/server.conf  &&
 perl -p -i -e "s/;push \"dhcp-option.*/push \"dhcp-option DNS 8.8.4.4\"/i"  /etc/openvpn/server.conf

#Edit user information
 perl -p -i -e "s/;user nobody/user nobody/i"  /etc/openvpn/server.conf  || echo user nobody >> /etc/openvpn/server.conf

 perl -p -i -e "s/;group nobody/group nobody/i"  /etc/openvpn/server.conf  || echo group nobody >> /etc/openvpn/server.conf


#Keys & Certificate using Easy-RSA
echo Generating key and certificate
mkdir -p /etc/openvpn/easy-rsa/keys

echo copying easy-rsa config files
cp -rf /usr/share/easy-rsa/2.0/* /etc/openvpn/easy-rsa || roll_back



echo  \#######  To setup certificate the following information is required, hit enter to use default values  \!\!\!   \ #######
# set default values for certificate setup

read -p "Enter Country Information[US]: " KEY_COUNTRY
KEY_COUNTRY=${KEY_COUNTRY:-US}
read -p "Province[NY]: " KEY_PROVINCE
KEY_PROVINCE=${KEY_PROVINCE:-NY}
read -p "City Name[New York]: " KEY_CITY
KEY_CITY=${KEY_CITY:-New York}
read -p "Organization[myOrganization]: " KEY_ORG
KEY_ORG=${KEY_ORG:-myOrganization}
read -p "Email[administrator@example.com]: " KEY_EMAIL
KEY_EMAIL=${KEY_EMAIL/\@/\\@}
KEY_EMAIL=${KEY_EMAIL:-'administrator\@example.com'}
read -p "CN [droplet.example.com] :  " KEY_CN
KEY_CN=${KEY_CN:-droplet.example.com}
read -p "OU[MyOrganizationalUnit]: " KEY_OU
KEY_OU=${KEY_OU:-MyOrganizationalUnit}

KEY_EMAIL=${KEY_EMAIL/@/\@}
echo Writing information to /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_COUNTRY.*/export KEY_COUNTRY=\"$KEY_COUNTRY\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_PROVINCE.*/export KEY_PROVINCE=\"$KEY_PROVINCE\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_CITY.*/export KEY_CITY=\"$KEY_CITY\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_ORG.*/export KEY_ORG=\"$KEY_ORG\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_EMAIL.*/export KEY_EMAIL=\"$KEY_EMAIL\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_OU.*/export KEY_OU=\"$KEY_OU\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/#export KEY_CN.*/export KEY_CN=\"$KEY_CN\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_CONFIG=.*/ export KEY_CONFIG=\/etc\/openvpn\/easy\-rsa\/openssl\-1\.0\.0\.cnf
/"  /etc/openvpn/easy-rsa/vars



# copy & configure
echo coyping openssl*.cnf to openvpn* dir
cp /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf || roll_back
perl -p -i -e "s/export KEY_ORG.*/export KEY_ORG=\"$KEY_ORG\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_EMAIL.*/export KEY_EMAIL=\"$KEY_EMAIL\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_OU.*/export KEY_OU=\"$KEY_OU\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/#export KEY_CN.*/export KEY_CN=\"$KEY_CN\"/"  /etc/openvpn/easy-rsa/vars
perl -p -i -e "s/export KEY_CONFIG=.*/ export KEY_CONFIG=\/etc\/openvpn\/easy\-rsa\/openssl\-1\.0\.0\.cnf
/"  /etc/openvpn/easy-rsa/vars



# copy & configure
echo coyping openssl*.cnf to openvpn* dir
cp /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf || roll_back

cd /etc/openvpn/easy-rsa && \
        source ./vars && \
        ./clean-all

 #Uncomment if you need script non-interactive
#perl -p -i -e "s/pkitool\" --interact/pkitool\"/"  /etc/openvpn/easy-rsa/build-ca

 ./build-ca

#create certificate
         # uncomment next line if you want to make certificate generation script non-interractive
        #perl -p -i -e "s/pkitool\" --interact/pkitool\"/"  /etc/openvpn/easy-rsa/build-key-server server

#Get Cert
./build-key-server server

./build-dh && cd /etc/openvpn/easy-rsa/keys

#comment out the next line if you used 1024 bit keys and Uncomment the 2nd line
cp dh2048.pem ca.crt server.crt server.key /etc/openvpn
#cp dh1024.pem ca.crt server.crt server.key /etc/openvpn


#Generate client certificates
cd /etc/openvpn/easy-rsa

         # uncomment next line if you want to make certificate generation script non-interractive
         #perl -p -i -e "s/pkitool\" --interact/pkitool\"/"  /etc/openvpn/easy-rsa/build-key

        ./build-key client

echo configuring iptables
#iptables configuration
 service iptables status | grep -i chain &&  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE &&  service iptables save || echo iptables not running

#enable IP forwarding
perl -p -i -e "s/net.ipv4.ip_forward[ ]+=[ ]+0/net.ipv4.ip_forward = 1/i"  /etc/sysctl.conf  && echo IP Forwarding enabled
sysctl -p

#tidy up
perl -p -i -e "s/;log-append /log-appendi /"  /etc/openvpn/server.conf

#Uncomment the next line if you used 1024 bit keys
perl -p -i -e "s/dh dh1024/dh dh2048/"  /etc/openvpn/server.conf

service openvpn start  && chkconfig openvpn on && echo installation completed.
) 2>&1 | tee /opt/openvpn_install.log

cd /etc/openvpn/easy-rsa && \