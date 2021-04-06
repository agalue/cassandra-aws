#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>
# Designed for CentOS/RHEL 8

######### CUSTOMIZED VARIABLES #########

onms_repo="stable"
onms_version="-latest-"

########################################

opennms_home=/opt/opennms
opennms_etc=$opennms_home/etc

echo "### Installing Redis..."

sudo yum -y -q install redis

echo "### Installing PostgreSQL 10..."

sudo yum install -y -q postgresql-server
sudo /usr/bin/postgresql-setup --initdb --unit postgresql
sudo sed -r -i "/^(local|host)/s/(peer|ident)/trust/g" /var/lib/pgsql/data/pg_hba.conf
sudo systemctl enable postgresql

echo "### Installing OpenNMS Dependencies from stable repository..."

sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-stable-rhel8.noarch.rpm
sudo rpm --import /etc/yum.repos.d/opennms-repo-stable-rhel8.gpg
sudo yum install -y -q jicmp jicmp6 jrrd jrrd2 rrdtool

echo "### Installing OpenNMS $onms_version from the $onms_repo repository..."

if [ "$onms_repo" != "stable" ]; then
  echo "### Installing OpenNMS $onms_repo Repository..."
  sudo yum remove -y -q opennms-repo-stable
  sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-$onms_repo-rhel8.noarch.rpm
  sudo rpm --import /etc/yum.repos.d/opennms-repo-$onms_repo-rhel8.gpg
fi

suffix=""
if [ "$onms_version" != "-latest-" ]; then
  suffix="-$onms_version"
fi
sudo yum install -y -q opennms-core$suffix opennms-webapp-jetty$suffix opennms-webapp-hawtio$suffix

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

echo "### Applying common configuration changes..."

# Disabling data choices
cat <<EOF | sudo tee $opennms_etc/org.opennms.features.datachoices.cfg
enabled=false
acknowledged-by=admin
acknowledged-at=Mon Jan 01 00\:00\:00 EDT 2018
EOF

# RRD Settings
cat <<EOF | sudo tee $opennms_etc/opennms.properties.d/rrd.properties
org.opennms.rrd.storeByGroup=true
org.opennms.rrd.storeByForeignSource=true
EOF

# Logging
sudo sed -r -i 's/value="DEBUG"/value="WARN"/' $opennms_etc/log4j2.xml
sudo sed -r -i '/manager/s/WARN/DEBUG/' $opennms_etc/log4j2.xml

echo "### Enabling CORS..."

webxml=$opennms_home/jetty-webapps/opennms/WEB-INF/web.xml
sudo cp $webxml $webxml.bak
sudo sed -r -i '/[<][!]--/{$!{N;s/[<][!]--\n  ([<]filter-mapping)/\1/}}' $webxml
sudo sed -r -i '/nrt/{$!{N;N;s/(nrt.*\n  [<]\/filter-mapping[>])\n  --[>]/\1/}}' $webxml

echo "### Configuring JVM..."

cat <<EOF | sudo tee $opennms_etc/opennms.conf
START_TIMEOUT=0
JAVA_HEAP_SIZE=2048
MAXIMUM_FILE_DESCRIPTORS=204800

ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Djava.net.preferIPv4Stack=true"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Xlog:gc:/opt/opennms/logs/gc.log"

ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseStringDeduplication"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseG1GC"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:G1RSetUpdatingPauseTimePercent=5"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:MaxGCPauseMillis=500"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:InitiatingHeapOccupancyPercent=70"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:ParallelGCThreads=1"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:ConcGCThreads=1"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+ParallelRefProcEnabled"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+AlwaysPreTouch"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseTLAB"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+ResizeTLAB"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:-UseBiasedLocking"

# Configure Remote JMX
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.port=18980"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.rmi.port=18980"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.local.only=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.ssl=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.authenticate=true"

# Listen on all interfaces
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dopennms.poller.server.serverHost=0.0.0.0"

# Accept remote RMI connections on this interface
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Djava.rmi.server.hostname=127.0.0.1"
EOF

# JMX Groups
cat <<EOF | sudo tee $opennms_etc/jmxremote.access
admin readwrite
jmx   readonly
EOF
