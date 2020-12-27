#!/bin/sh
set -e

# Mandatory environmental variables: 
# export SETUP_USERNAME=johndoe
# export SETUP_GITHUB_USERNAME=johndoe
# export SETUP_IPv4=192.168.1.1/24
# export SETUP_IPv4GATEWAY=192.168.1.1

# Optional environmental variable
# SETUP_HOSTNAME=mycoolhostname


############################################################
# Do not change anything below this line
############################################################

# Check user related configuration
if [ -z "$SETUP_USERNAME" ]; then
    echo "Must provide SETUP_USERNAME of non privileged user" 1>&2
    exit 1
fi

if [ ! -d "/home/${SETUP_USERNAME}" ]
then
    printf "\n\033[31m[NOK]\033[0m\t%s\n" "The home folder of user ${SETUP_USERNAME} can not be found"
    exit 1
fi

if [ -z "$SETUP_GITHUB_USERNAME" ]; then
    printf "\n\033[31m[NOK]\033[0m\t%s\n" "The variable SETUP_GITHUB_USERNAME is not set."
    exit 1
fi

if id "${SETUP_USERNAME}" >/dev/null 2>&1; then
    printf "\n\033[32m[OK]\033[0m\t%s\n" "user ${SETUP_USERNAME} found"
else
    printf "\n\033[31m[NOK]\033[0m\t%s\n" "user ${SETUP_USERNAME} NOT found\n"
    exit 1
fi

# Check IPv4 and IPv4 gateway
if [ -z "$SETUP_IPv4" ]; then
    printf "\n\033[31m[NOK]\033[0m\t%s\n\t%s\n\n" "Must provide SETUP_IPv4 with the IP address of the machine" "E.g.: SETUP_IPv4=192.168.1.10/24"
    exit 1
fi



# Update latest patches
apt -y update && apt -y upgrade

# Set the hostname
if [ ! -z "$SETUP_HOSTNAME" ]; then
    # printf "About to re-set the hostname to ${SETUP_HOSTNAME}"
    printf "\n\033[33m[INFO]\033[0m\t%s\n" "About to re-set the hostname to ${SETUP_HOSTNAME}"

    hostnamectl set-hostname ${SETUP_HOSTNAME}

    # Update the /etc/hosts file
    ipv4_localhost_re="127\.0\.1\.1"
    sed -i "s/^\($ipv4_localhost_re\(\s.*\)*\s\).*$/\1${SETUP_HOSTNAME}/" /etc/hosts
    sed -i "s/^\(::1\(\s.*\)*\s\).*$/\1${SETUP_HOSTNAME}/" /etc/hosts    
fi

# Configure sudo
bash -c 'echo "# Allow members of group sudo to execute any command, without the need to provide your password" > /etc/sudoers.d/51_sudo_without_password'
bash -c 'echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers.d/51_sudo_without_password'
chmod 0440 /etc/sudoers.d/51_sudo_without_password

# set up proper vi for root:
tee /root/.vimrc <<EOF
set mouse-=a
syntax on
EOF

# Install Netplan.io to be more consistent with Ubuntu
apt install -y netplan.io

# configure networking via netplan.io
tee /etc/netplan/01-network-configuration.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - ${SETUP_IPv4}
      gateway4: ${SETUP_IPv4GATEWAY}
      nameservers:
        search: [knutsel.space, egbert.space]
        addresses:
          - 1.1.1.1
          - 1.0.0.1
EOF

# Disable NetworkManager
systemctl stop NetworkManager || true
systemctl disable NetworkManager || true
apt purge --auto-remove -y network-manager
apt purge --auto-remove -y wpasupplicant

# Enable systemd-networkd
systemctl start systemd-networkd
systemctl enable systemd-networkd

# Enable netplan.io
/usr/sbin/netplan apply

# Set SSH keys for user

mkdir -p /home/${SETUP_USERNAME}/.ssh
chown ${SETUP_USERNAME}:${SETUP_USERNAME} /home/${SETUP_USERNAME}/.ssh
curl -s https://github.com/${SETUP_GITHUB_USERNAME}.keys > /home/${SETUP_USERNAME}/.ssh/authorized_keys

# Disable root login via SSH
sed -i '/^[#?]PermitRootLogin[ \t].*$/{ s//PermitRootLogin no/g; }' /etc/ssh/sshd_config
# Disable password authentication
sed -i '/^[#?]PasswordAuthentication[ \t].*$/{ s//PasswordAuthentication no/g; }' /etc/ssh/sshd_config
# Restart the ssh daemon
systemctl restart sshd

# Install packages
apt install -y curl git net-tools fail2ban

pkgs='docker-ce'
if ! dpkg -s $pkgs >/dev/null 2>&1; then
#   echo 'docker-ce not installed. Installing....'
  printf "\n\033[33m[INFO]\033[0m\t%s\n" "docker-ce not installed. Installing...."
  curl -fsSL test.docker.com -o get-docker.sh && sh get-docker.sh
else
#   echo "docker-ce already installed. Skipping..."
  printf "\n\033[32m[INFO]\033[0m\t%s\n" "docker-ce already installed. Skipping..."
fi

# Add non-privileged user to the docker group
usermod -aG docker $SETUP_USERNAME 
