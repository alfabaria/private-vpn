# private-vpn
Automation script for installing vpn service on ubuntu server.

## How to use

`ssh root@<YOUR_VPN_SERVER> "sudo wget https://raw.githubusercontent.com/alfabaria/private-vpn/main/ikev2-server-deploy.sh -O ikev2-server-deploy.sh;  sudo chmod +x ikev2-server-deploy.sh; sudo sh ikev2-server-deploy.sh <VPN_USERNAME> <VPN_PASSWORD>;"`

### Variable
**<YOUR_VPN_SERVER>** : Replace with your VPS ip <br/>
**<VPN_USERNAME>** : Replace with VPN username you want (optianal you can leave it blank) <br/>
**<VPN_PASSWORD>** : Replace with VPN password you want (optianal you can leave it blank) <br/>
