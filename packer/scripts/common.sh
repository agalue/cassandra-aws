#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

set -e

######### CUSTOMIZED VARIABLES #########

timezone="America/New_York"
max_files="100000"

########################################

mkdir -p /tmp/sources/

echo "### Configuring Timezone..."

sudo ln -sf /usr/share/zoneinfo/$timezone /etc/localtime

echo "### Installing common packages..."

sudo yum -y update
. /etc/os-release
if [ "$ID" == "amzn" ]; then
  sudo amazon-linux-extras install epel -y
else
  sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
fi
sudo yum -y install jq vim net-snmp net-snmp-utils git dstat htop nmap-ncat tree telnet curl nmon haveged

echo "### Enabling haveged..."

sudo systemctl enable haveged

echo "### Configuring and enabling Net-SNMP..."

snmp_cfg=/etc/snmp/snmpd.conf
sudo cp $snmp_cfg $snmp_cfg.original
cat <<EOF | sudo tee $snmp_cfg
rocommunity public default
syslocation AWS
syscontact Account Manager
dontLogTCPWrappersConnects yes
disk /
EOF
sudo chmod 600 $snmp_cfg
sudo systemctl enable snmpd

echo "### Configuring Kernel..."

sudo sed -i 's/^\(.*swap\)/#\1/' /etc/fstab

cat <<EOF | sudo tee /etc/sysctl.d/application.conf
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=10

net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=40960
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

net.ipv4.tcp_window_scaling=1
net.core.netdev_max_backlog=2500
net.core.somaxconn=65000

vm.swappiness=1
vm.zone_reclaim_mode=0
vm.max_map_count=1048575
EOF

cat <<EOF | sudo tee /etc/security/limits.d/application.conf
* soft nofile $max_files
* hard nofile $max_files
EOF

cat <<EOF | sudo tee /etc/systemd/system/disable-thp.service
# For more information: https://tobert.github.io/tldr/cassandra-java-huge-pages.html

[Unit]
Description=Disable Transparent Huge Pages (THP)

[Service]
Type=simple
ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable disable-thp
