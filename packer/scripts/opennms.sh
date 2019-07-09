#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

######### CUSTOMIZED VARIABLES #########

onms_repo="stable"
onms_version="-latest-"

########################################

opennms_home=/opt/opennms
opennms_etc=$opennms_home/etc

echo "### Installing Common Packages..."

sudo yum -y -q install haveged redis
sudo systemctl enable haveged

echo "### Installing PostgreSQL 10..."

sudo amazon-linux-extras install postgresql10 -y
sudo yum install -y -q postgresql-server
sudo /usr/bin/postgresql-setup --initdb --unit postgresql
sudo sed -r -i "/^(local|host)/s/(peer|ident)/trust/g" /var/lib/pgsql/data/pg_hba.conf
sudo systemctl enable postgresql

echo "### Installing OpenNMS Dependencies from stable repository..."

sudo sed -r -i '/name=Amazon Linux 2/a exclude=rrdtool-*' /etc/yum.repos.d/amzn2-core.repo
sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-stable-rhel7.noarch.rpm
sudo rpm --import /etc/yum.repos.d/opennms-repo-stable-rhel7.gpg
sudo yum install -y -q jicmp jicmp6 jrrd jrrd2 rrdtool 'perl(LWP)' 'perl(XML::Twig)'

echo "### Installing OpenNMS..."

if [ "$onms_repo" != "stable" ]; then
  echo "### Installing OpenNMS $onms_repo Repository..."
  sudo yum remove -y -q opennms-repo-stable
  sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-$onms_repo-rhel7.noarch.rpm
  sudo rpm --import /etc/yum.repos.d/opennms-repo-$onms_repo-rhel7.gpg
fi

if [ "$onms_version" == "-latest-" ]; then
  echo "### Installing latest OpenNMS from $onms_repo Repository..."
  sudo yum install -y -q opennms-core opennms-webapp-jetty opennms-webapp-hawtio
else
  echo "### Installing OpenNMS version $onms_version from $onms_repo Repository..."
  sudo yum install -y -q opennms-core-$onms_version opennms-webapp-jetty-$onms_version opennms-webapp-hawtio-$onms_version
fi

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

# Fixing default JMX credentials for Cassandra
sudo sed -r -i 's/cassandra-username/cassandra/g' $opennms_etc/poller-configuration.xml
sudo sed -r -i 's/cassandra-password/cassandra/g' $opennms_etc/poller-configuration.xml
sudo sed -r -i 's/cassandra-username/cassandra/g' $opennms_etc/collectd-configuration.xml
sudo sed -r -i 's/cassandra-password/cassandra/g' $opennms_etc/collectd-configuration.xml

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
