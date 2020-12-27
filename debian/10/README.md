# Configure Debian 10 machine

## Usage

```sh
export SETUP_USERNAME=egbert
export SETUP_GITHUB_USERNAME=egbertp
export SETUP_IPv4=192.168.1.10/24
export SETUP_IPv4GATEWAY=192.168.1.1
export SETUP_HOSTNAME=mycoolhostname

$ curl -fsSL https://raw.githubusercontent.com/egbertp/setup-scripts/master/debian/10/setup.sh -o setup.sh && sh setup.sh
```

## What this script does

This script installs and configures Debian 10 based systems.

Installation includes: 

* docker-ce
* netplan.io
* fail2ban
* curl
* net-tools
* htop
* mtr

Configuration includes: 
* removal of `NetworkManager`
* removal of `wpasupplicant`
* enabeling `systemd-networkd`
* configure SSH daemon
    * PermitRootLogin no
    * PasswordAuthentication no

