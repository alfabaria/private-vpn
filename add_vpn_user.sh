#!/bin/bash
#
# Script to add/update a VPN user for both IPsec/L2TP and IPsec/Ikev2

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
SYS_DT=$(date +%F-%T | tr ':' '_')

exiterr()  { echo "Error: $1" >&2; exit 1; }
conf_bk() { /bin/cp -f "$1" "$1.old-$SYS_DT" 2>/dev/null; }

show_intro() {
cat <<'EOF'

Welcome! Use this script to add or update a VPN user account for both
IPsec/L2TP, IPsec/XAuth or IPsec/Ikev2 modes.

If the username you specify already exists, it will be updated
with the new password. Otherwise, a new VPN user will be added.
EOF
}

add_vpn_user() {
  if [ "$(id -u)" != 0 ]; then
    exiterr "Script must be run as root. Try 'sudo bash $0'"
  fi
  if [ ! -f /etc/ppp/chap-secrets ] || [ ! -f /etc/ipsec.d/passwd ] || [ ! -f /etc/ipsec.secrets ]; then
cat 1>&2 <<'EOF'
Error: Your must first set up the IPsec VPN server before adding VPN users.
       See: https://github.com/alfabaria/private-vpn/
EOF
    exit 1
cat 1>&2 <<EOF
Usage: sudo bash $0 'username_to_add' 'password'
       sudo bash $0 'username_to_update' 'new_password'
You may also run this script interactively without arguments.
EOF
    exit 1
  fi
  VPN_USER=$1
  VPN_PASSWORD=$2
  if [ -z "$VPN_USER" ] || [ -z "$VPN_PASSWORD" ]; then
    show_intro
    echo
    echo "List of existing VPN usernames:"
    cut -f1 -d : /etc/ipsec.d/passwd | LC_ALL=C sort
    echo
    echo "Enter the VPN username you want to add or update."
    read -rp "Username: " VPN_USER
    if [ -z "$VPN_USER" ]; then
      echo "Abort. No changes were made." >&2
      exit 1
    fi
    read -rp "Password: " VPN_PASSWORD
    if [ -z "$VPN_PASSWORD" ]; then
      echo "Abort. No changes were made." >&2
      exit 1
    fi
  fi
  if printf '%s' "$VPN_USER $VPN_PASSWORD" | LC_ALL=C grep -q '[^ -~]\+'; then
    exiterr "VPN credentials must not contain non-ASCII characters."
  fi
  case "$VPN_USER $VPN_PASSWORD" in
    *[\\\"\']*)
      exiterr "VPN credentials must not contain these special characters: \\ \" '"
      ;;
  esac
  if [ -n "$1" ] && [ -n "$2" ]; then
    show_intro
  fi
cat <<EOF

================================================

VPN user to add or update:

Username: $VPN_USER
Password: $VPN_PASSWORD

Write these down. You'll need them to connect!

================================================

EOF
  printf "Do you want to continue? [Y/n] "
  read -r response
  case $response in
    [yY][eE][sS]|[yY]|'')
      echo
      echo "Adding or updating VPN user..."
      echo
      ;;
    *)
      echo "Abort. No changes were made."
      exit 1
      ;;
  esac
  # Backup config files
  conf_bk "/etc/ppp/chap-secrets"
  conf_bk "/etc/ipsec.d/passwd"
  conf_bk "/etc/ipsec.secrets"
  # Add or update VPN user
  sed -i "/^\"$VPN_USER\" /d" /etc/ppp/chap-secrets
cat >> /etc/ppp/chap-secrets <<EOF
"$VPN_USER" l2tpd "$VPN_PASSWORD" *
EOF
  sed -i "/^\"$VPN_USER\" /d" /etc/ipsec.secrets
cat >> /etc/ipsec.secrets <<EOF
"$VPN_USER %any% : EAP "$VPN_PASSWORD"
EOF
  sed -i '/^'"$VPN_USER"':\$1\$/d' /etc/ipsec.d/passwd
cat >> /etc/ipsec.d/passwd <<EOF
$VPN_USER:$VPN_PASSWORD:xauth-psk
EOF
  # Update file attributes
  chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd*
cat <<'EOF'
Done!

Note: All VPN users will share the same IPsec PSK.
      If you forgot the PSK, check /etc/ipsec.secrets.

EOF
}

## Defer until we have the complete script
add_vpn_user "$@"

exit 0
