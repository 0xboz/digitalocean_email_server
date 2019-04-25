#!/usr/bin/env bash
# Basic sever setup for DigitalOcean Debian 9
# Change sources.list
sed -i -e '$ a\apt_preserve_sources_list: true' /etc/cloud/cloud.cfg
# Comment out all lines
sed -i -e 's/^#*/#/' /etc/apt/sources.list
sed -i -e 's/^#*/#/' /etc/cloud/templates/sources.list.debian.tmpl
# Create customSources.list
echo 'deb http://deb.debian.org/debian stretch main contrib non-free' >> /etc/apt/sources.list.d/customSources.list
echo 'deb http://deb.debian.org/debian-security/ stretch/updates main contrib non-free' >> /etc/apt/sources.list.d/customSources.list
echo 'deb http://deb.debian.org/debian stretch-updates main contrib non-free' >> /etc/apt/sources.list.d/customSources.list
echo 'deb http://deb.debian.org/debian stretch-backports main contrib non-free' >> /etc/apt/sources.list.d/customSources.list
# Non-interactive
export DEBIAN_FRONTEND=noninteractive
# Update and Upgrade
apt -y update && apt -y upgrade && apt -y autoremove
# Obtain IP
IP="$(ifconfig eth0 | grep inet | awk '/[0-9]\./{print $2}')"
# Custom prompt
echo "export PS1=\"\[\033[0m\]\[\033[31m\]\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\[\033[32m\]"$IP" \[\033[40m\]\[\033[33m\]$(hostname -f)\[\033[0m\]\[\033[37m\] in \[\033[32m\]\w\n\[\033[37m\]\$ \"" > ~/.bash_profile
source ~/.bash_profile
# Install basic firewall ufw
apt install -y ufw
ufw allow 'OpenSSH'
yes | ufw enable
# Reboot
reboot
