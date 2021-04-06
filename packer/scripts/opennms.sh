#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>
# Designed for CentOS/RHEL 8

set -e

######### CUSTOMIZED VARIABLES #########

onms_repo="stable"
onms_version="-latest-"

########################################

opennms_home=/opt/opennms
opennms_etc=$opennms_home/etc

echo "### Installing Redis..."

sudo dnf -y install redis

echo "### Installing PostgreSQL 10..."

sudo dnf install -y postgresql-server
sudo /usr/bin/postgresql-setup --initdb --unit postgresql
sudo sed -r -i "/^(local|host)/s/(peer|ident)/trust/g" /var/lib/pgsql/data/pg_hba.conf
sudo systemctl enable postgresql

echo "### Installing OpenNMS Dependencies from the stable repository..."

sudo dnf install -y http://dnf.opennms.org/repofiles/opennms-repo-stable-rhel8.noarch.rpm
sudo rpm --import /etc/dnf.repos.d/opennms-repo-stable-rhel8.gpg
sudo dnf install -y jicmp jicmp6
sudo dnf install -y java-11-openjdk-devel

echo "### Installing OpenNMS $onms_version from the $onms_repo repository..."

if [ "$onms_repo" != "stable" ]; then
  sudo dnf remove -y opennms-repo-stable
  sudo dnf install -y http://dnf.opennms.org/repofiles/opennms-repo-$onms_repo-rhel8.noarch.rpm
  sudo rpm --import /etc/dnf.repos.d/opennms-repo-$onms_repo-rhel8.gpg
fi
suffix=""
if [ "$onms_version" != "-latest-" ]; then
  suffix="-$onms_version"
fi
sudo dnf install -y opennms-core$suffix opennms-webapp-jetty$suffix opennms-webapp-hawtio$suffix

echo "### Initializing GIT at $opennms_etc..."

cd $opennms_etc
sudo git config --global user.name "OpenNMS"
sudo git config --global user.email "support@opennms.org"
sudo git init .
sudo git add .
sudo git commit -m "OpenNMS Installed."
cd

echo "### Copying external configuration files..."

src_dir=/tmp/sources
sudo chown -R root:root $src_dir/
sudo rsync -avr $src_dir/ /opt/opennms/etc/

echo "### Fix logging..."

sudo sed -r -i 's/value="DEBUG"/value="WARN"/' $opennms_etc/log4j2.xml
sudo sed -r -i '/manager/s/WARN/DEBUG/' $opennms_etc/log4j2.xml

echo "### Enabling CORS..."

webxml=$opennms_home/jetty-webapps/opennms/WEB-INF/web.xml
sudo cp $webxml $webxml.bak
sudo sed -r -i '/[<][!]--/{$!{N;s/[<][!]--\n  ([<]filter-mapping)/\1/}}' $webxml
sudo sed -r -i '/nrt/{$!{N;N;s/(nrt.*\n  [<]\/filter-mapping[>])\n  --[>]/\1/}}' $webxml

echo "### Selecting Java 11..."

sudo $opennms_home/bin/runjava -S /usr/lib/jvm/java-11/bin/java

echo "### Initializing the database..."

sudo systemctl start postgresql
sleep 5
sudo $opennms_home/bin/install -dis

echo "### Done."