# private-vpn
Automation script for installing vpn service on ubuntu server.

## How to use
### Install and setup new VPN

****execute below command from your local machine***
```shell
ssh root@<YOUR_VPN_SERVER> "sudo wget https://raw.githubusercontent.com/alfabaria/private-vpn/main/ikev2-server-deploy.sh -O ikev2-server-deploy.sh; wget https://raw.githubusercontent.com/alfabaria/private-vpn/main/add_vpn_user.sh -O add_vpn_user.sh; sudo chmod +x ikev2-server-deploy.sh; chmod +x add_vpn_user.sh; sudo sh ikev2-server-deploy.sh <VPN_USERNAME> <VPN_PASSWORD>;"
```

### Add or update vpn user
****execute below command from your remote machine***
```shell
sudo sh add_vpn_user.sh
```

### Variable
**<YOUR_VPS_SERVER>** : Replace with your VPS ip <br/>
**<PROXY_USERNAME>** : Replace with Proxy username you want to use <br/>
**<PROXY_USERNAME>** : Replace with Proxy password you want to use <br/><br/>


# proxy-server
Automation script for installing squid proxy service on ubuntu server.

## How to use
### Install and setup new Proxy

****execute below command from your local machine***
```shell
ssh root@<YOUR_VPS_SERVER> "sudo wget https://raw.githubusercontent.com/alfabaria/private-vpn/main/install-proxy.sh -O install-proxy.sh; sudo chmod +x install-proxy.sh; sudo sh install-proxy.sh <PROXY_USERNAME> <PROXY_PASSWORD>;"
```
