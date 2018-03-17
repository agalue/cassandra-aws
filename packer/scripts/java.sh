#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

echo "### Downloading and installing Oracle JDK..."

java_url="http://download.oracle.com/otn-pub/java/jdk/8u161-b12/2f38c3b165be4555a1fa6e98c45e0808/jdk-8u161-linux-x64.rpm"
java_rpm=/tmp/jdk8-linux-x64.rpm

wget -c --quiet --header "Cookie: oraclelicense=accept-securebackup-cookie" -O $java_rpm $java_url

if [ ! -s $java_rpm ]; then
  echo "FATAL: Cannot download Java from $java_url. Using OpenJDK instead ..."
  sudo yum -y -q install java-1.8.0-openjdk java-1.8.0-openjdk-devel
else
  sudo yum install -y -q $java_rpm
  sudo rm -f $java_rpm
fi
