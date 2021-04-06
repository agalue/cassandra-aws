#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>
# Designed for CentOS/RHEL 8

set -e

# Set the USE_LATEST_JAVA environment variable in order to use latest Java instead of Java 8

echo "### Downloading and installing latest OpenJDK..."

if [ "$USE_LATEST_JAVA" != "" ]; then
  sudo dnf install -y java-11-openjdk-devel
else
  sudo dnf install -y java-1.8.0-openjdk-devel
fi
