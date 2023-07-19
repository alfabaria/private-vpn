#!/bin/bash

bail_out() {
	echo -e "\033[31;7mThis script supports only Ubuntu 18.04 and 20.04 . Terminating.\e[0m"
	exit 1
}

if [ $(lsb_release -i -s) != "Ubuntu" ] || [ $(lsb_release -r -s) != "18.04" ] || [ $(lsb_release -r -s) != "20.04" ]; then 
	bail_out
fi

export SHARED_KEY=$(uuidgen)
export IP=$(curl -s  https://ipinfo.io/ip)
export COUNTRY=$(curl -s  https://ipinfo.io/country | awk '{print tolower($0)}')
export DEFAULT_INTERFACE=$(route | grep '^default' | grep -o '[^ ]*$')

VPN_USER=$1
VPN_PASSWORD=$2

if [ -z "$VPN_USER" ] || [ -z "$VPN_PASSWORD" ]; then
    VPN_USER="default-vpn-$COUNTRY"
    VPN_PASSWORD="VpnPr1v@t3$COUNTRY"
fi

echo "VPN Address : $IP"
echo "Shared key (PSK) : $SHARED_KEY"
echo "VPN User : $VPN_USER"
echo "VPN Password : $VPN_PASSWORD"
echo ""
echo -e "Press enter to continue...\n"; read

apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade

# skips interactive dialog for iptables-persistent installer
export DEBIAN_FRONTEND=noninteractive
apt-get -y install strongswan libcharon-extra-plugins moreutils strongswan-pki iptables-persistent xl2tpd ppp

# set service to always run
sudo systemctl start strongswan
sudo systemctl enable strongswan
sudo systemctl start xl2tpd
sudo systemctl enable xl2tpd

#=========== 
# Creating a Certificate Authority
#===========
mkdir -p ~/pki/cacerts
mkdir -p ~/pki/certs
mkdir -p ~/pki/private
chmod 700 ~/pki
ipsec pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/ca-key.pem
ipsec pki --self --ca --lifetime 3650 --in ~/pki/private/ca-key.pem \
    --type rsa --dn "CN=VPN root CA" --outform pem > ~/pki/cacerts/ca-cert.pem
ipsec pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/server-key.pem
ipsec pki --pub --in ~/pki/private/server-key.pem --type rsa \
    | ipsec pki --issue --lifetime 1825 \
        --cacert ~/pki/cacerts/ca-cert.pem \
        --cakey ~/pki/private/ca-key.pem \
        --dn "CN=${IP}" --san "${IP}" \
        --flag serverAuth --flag ikeIntermediate --outform pem \
    >  ~/pki/certs/server-cert.pem

sudo cp -r ~/pki/* /etc/ipsec.d/

#=========== 
# STRONG SWAN CONFIG
#===========

## Create /etc/ipsec.conf

cat << EOF > /etc/ipsec.conf
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    ike=aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024,aes256-sha256-modp2048,aes128-sha256-modp2048,aes256-sha1-modp2048,aes128-sha1-modp2048
    esp=aes256-sha256,aes256-sha1,3des-sha1,aes256-sha256-modp2048,aes128-sha256-modp2048,aes256-sha1-modp2048,aes128-sha1-modp2048
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=%any
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightdns=8.8.8.8,8.8.4.4
    rightsourceip=10.10.10.0/24
    authby=secret

conn ikev2-vpn-windows
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    leftfirewall=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@server_name_or_ip
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.100.0/24
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
    ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!

conn L2TP
    left=%defaultroute
    leftid=@server_name_or_ip
    right=%any
    encapsulation=yes
    authby=secret
    pfs=no
    rekey=no
    keyingtries=5
    dpddelay=30
    dpdtimeout=120
    dpdaction=clear
    ikev2=never
    ike=aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024,aes256-sha256-modp2048,aes128-sha256-modp2048,aes256-sha1-modp2048,aes128-sha1-modp2048
    esp=aes256-sha256,aes256-sha1,3des-sha1,aes256-sha256-modp2048,aes128-sha256-modp2048,aes256-sha1-modp2048,aes128-sha1-modp2048
    ikelifetime=24h
    salifetime=24h
    sha2-truncbug=no
    auto=add
    leftprotoport=17/1701
    rightprotoport=17/%any
    type=transport
EOF

sed -i "s/@server_name_or_ip/${IP}/g" /etc/ipsec.conf


## Create xl2tpd config 
cat << EOF > /etc/xl2tpd/xl2tpd.conf
[global]
port = 1701

[lns default]
ip range = 192.168.42.10-192.168.42.250
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

### Set xl2tpd options
cat << EOF > /etc/ppp/options.xl2tpd
+mschap-v2
ipcp-accept-local
ipcp-accept-remote
noccp
auth
mtu 1280
mru 1280
proxyarp
lcp-echo-failure 4
lcp-echo-interval 30
connect-delay 5000
ms-dns 8.8.8.8
ms-dns 8.8.4.4
EOF

## Create VPN credentials L2TP
cat << EOF > /etc/ppp/chap-secrets
$VPN_USER l2tpd "$VPN_PASSWORD" *
EOF

cat << EOF > /etc/ipsec.d/passwd
$VPN_USER:$VPN_PASSWORD:xauth-psk
EOF

## add secrets to /etc/ipsec.secrets
cat << EOF > /etc/ipsec.secrets
: PSK $SHARED_KEY
: RSA "server-key.pem"
$VPN_USER %any% : EAP "$VPN_PASSWORD"
EOF

sed -i "s/server_name_or_ip/${IP}/g" /etc/ipsec.secrets

#=========== 
# IPTABLES + FIREWALL
#=========== 

# remove if there were UFW rules
ufw disable
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -Z

# ssh rules

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# loopback 
iptables -A INPUT -i lo -j ACCEPT

# ipsec

iptables -A INPUT -p udp --dport  500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT

iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.10.10.10/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.10.10/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.10.100.0/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.100.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o ${DEFAULT_INTERFACE} -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o ${DEFAULT_INTERFACE} -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.10.100.0/24 -o ${DEFAULT_INTERFACE} -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.100.0/24 -o ${DEFAULT_INTERFACE} -j MASQUERADE
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.10/24 -o ${DEFAULT_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.100.0/24 -o ${DEFAULT_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
iptables -I INPUT -p udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT
iptables -I FORWARD -i ${DEFAULT_INTERFACE} -o ppp+ -m conntrack --ctstate "RELATED,ESTABLISHED" -j ACCEPT
iptables -I FORWARD -i ppp+ -o ${DEFAULT_INTERFACE} -j ACCEPT
iptables -I FORWARD -i ppp+ -o ppp+ -j ACCEPT
iptables -I FORWARD -i ${DEFAULT_INTERFACE} -d "192.168.43.0/24" -m conntrack --ctstate "RELATED,ESTABLISHED" -j ACCEPT
iptables -I FORWARD -s "192.168.43.0/24" -o ${DEFAULT_INTERFACE} -j ACCEPT
iptables -I FORWARD -s "192.168.43.0/24" -o ppp+ -j ACCEPT
iptables -t nat -I POSTROUTING -s "192.168.43.0/24" -o ${DEFAULT_INTERFACE} -m policy --dir out --pol none -j MASQUERADE
iptables -t nat -I POSTROUTING -s "192.168.42.0/24" -o ${DEFAULT_INTERFACE} -j MASQUERADE

iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP

netfilter-persistent save
netfilter-persistent reload

#=======
# CHANGES TO SYSCTL (/etc/sysctl.conf)
#=======

sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
sed -i "s/#net.ipv4.conf.all.accept_redirects = 0/net.ipv4.conf.all.accept_redirects = 0/" /etc/sysctl.conf
sed -i "s/#net.ipv4.conf.all.send_redirects = 0/net.ipv4.conf.all.send_redirects = 0/" /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "net.ipv4.ip_no_pmtu_disc = 1" >> /etc/sysctl.conf

#=======
# REBOOT
#=======

echo ""
echo "Looks like the script has finished successfully."
echo ""
echo "VPN Address : $IP"
echo "Shared key (PSK) : $SHARED_KEY"
echo "VPN User : $VPN_USER"
echo "VPN Password : $VPN_PASSWORD"
echo ""
echo "The system will now be re-booted and your VPN server should be up and running right after that."
echo ""

reboot
