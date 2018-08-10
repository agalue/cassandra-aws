#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

######### CUSTOMIZED VARIABLES #########

onms_repo="stable"
onms_version="-latest-"
hawtio_version="1.4.68"

########################################

opennms_home=/opt/opennms
opennms_etc=$opennms_home/etc

echo "### Installing Common Packages..."

sudo yum -y -q install haveged redis
sudo systemctl enable haveged

echo "### Installing PostgreSQL 10..."

sudo amazon-linux-extras install postgresql10 -y
sudo yum install -y -q yum install postgresql-server
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
  sudo yum install -y -q opennms-core opennms-webapp-jetty
else
  echo "### Installing OpenNMS version $onms_version from $onms_repo Repository..."
  sudo yum install -y -q opennms-core-$onms_version opennms-webapp-jetty-$onms_version
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
cat <<EOF > $opennms_etc/org.opennms.features.datachoices.cfg
enabled=false
acknowledged-by=admin
acknowledged-at=Mon Jan 01 00\:00\:00 EDT 2018
EOF

# Fixing default JMX credentials for Cassandra
sed -r -i 's/cassandra-username/cassandra/g' $opennms_etc/poller-configuration.xml
sed -r -i 's/cassandra-password/cassandra/g' $opennms_etc/poller-configuration.xml
sed -r -i 's/cassandra-username/cassandra/g' $opennms_etc/collectd-configuration.xml
sed -r -i 's/cassandra-password/cassandra/g' $opennms_etc/collectd-configuration.xml

# RRD Settings
cat <<EOF > $opennms_etc/opennms.properties.d/rrd.properties
org.opennms.rrd.storeByGroup=true
org.opennms.rrd.storeByForeignSource=true
EOF

# Logging
sed -r -i 's/value="DEBUG"/value="WARN"/' $opennms_etc/log4j2.xml
sed -r -i '/manager/s/WARN/DEBUG/' $opennms_etc/log4j2.xml

echo "### Installing Hawtio version $hawtio_version..."

hawtio_url=https://oss.sonatype.org/content/repositories/public/io/hawt/hawtio-default/$hawtio_version/hawtio-default-$hawtio_version.war
hawtio_war=$opennms_home/jetty-webapps/hawtio.war
sudo wget -qO $hawtio_war $hawtio_url && \
  sudo unzip -qq $hawtio_war -d $opennms_home/jetty-webapps/hawtio && \
  sudo rm -f $hawtio_war

echo "### Enabling CORS..."

webxml=$opennms_home/jetty-webapps/opennms/WEB-INF/web.xml
sudo cp $webxml $webxml.bak
sudo sed -r -i '/[<][!]--/{$!{N;s/[<][!]--\n  ([<]filter-mapping)/\1/}}' $webxml
sudo sed -r -i '/nrt/{$!{N;N;s/(nrt.*\n  [<]\/filter-mapping[>])\n  --[>]/\1/}}' $webxml
