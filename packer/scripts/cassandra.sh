#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>
# Designed for CentOS/RHEL 8

set -e

######### CUSTOMIZED VARIABLES #########

repo_version="311x"

########################################

echo "### Downloading and installing Cassandra $repo_version..."

tmp_repo=/tmp/cassandra.repo 
cat <<EOF > $tmp_repo
[cassandra]
name=Apache Cassandra
baseurl=https://www.apache.org/dist/cassandra/redhat/${repo_version}/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.apache.org/dist/cassandra/KEYS
EOF
sudo mv $tmp_repo /etc/yum.repos.d

sudo dnf install -y cassandra cassandra-tools

echo "### Done."