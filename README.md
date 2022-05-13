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
**<YOUR_VPN_SERVER>** : Replace with your VPS ip <br/>
**<VPN_USERNAME>** : Replace with VPN username you want (optianal you can leave it blank) <br/>
**<VPN_PASSWORD>** : Replace with VPN password you want (optianal you can leave it blank) <br/>
