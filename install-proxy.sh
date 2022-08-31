#!/bin/bash

SQUID_USER=$1
SQUID_PASSWORD=$2
IP=$(curl -s https://ipinfo.io/ip)

/usr/bin/apt update
/usr/bin/apt -y install squid apache2-utils

/usr/bin/htpasswd -b -c /etc/squid/passwd $SQUID_USER $SQUID_PASSWORD

/bin/rm -f /etc/squid/squid.conf
/usr/bin/touch /etc/squid/blacklist.acl
/usr/bin/wget --no-check-certificate -O /etc/squid/squid.conf https://raw.githubusercontent.com/alfabaria/private-vpn/main/squid.conf.txt

/sbin/iptables -I INPUT -p tcp --dport 3128 -j ACCEPT
/sbin/iptables-save

service squid restart
update-rc.d squid defaults

echo ""
echo "Looks like the script has finished successfully."
echo ""
echo "Proxy Address : $IP"
echo "Proxy User : $SQUID_USER"
echo "Proxy Password : $SQUID_PASSWORD"
echo ""
echo "Set your proxy server in your browser to http://$IP:3128"
echo ""
