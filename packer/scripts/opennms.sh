#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

######### CUSTOMIZED VARIABLES #########

onms_repo="bleeding"
onms_version="-latest-"
grafana_version="5.1.3"
hawtio_version="1.4.68"
pg_repo_version="9.6-3"

########################################

opennms_home=/opt/opennms
opennms_etc=$opennms_home/etc

echo "### Installing EPEL Repository..."

sudo yum -y -q install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

echo "### Installing Common Packages..."

sudo yum -y -q install haveged redis
sudo systemctl enable haveged

echo "### Installing PostgreSQL from repository version $pg_repo_version..."

pg_version=`echo $pg_repo_version | sed 's/-.//'`
pg_family=`echo $pg_version | sed 's/\.//'`

sudo yum install -y -q https://download.postgresql.org/pub/repos/yum/$pg_version/redhat/rhel-7-x86_64/pgdg-centos$pg_family-$pg_repo_version.noarch.rpm
sudo sed -i -r 's/[$]releasever/7/g' /etc/yum.repos.d/pgdg-$pg_family-centos.repo
sudo yum install -y -q postgresql$pg_family postgresql$pg_family-server postgresql$pg_family-contrib repmgr$pg_family

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
