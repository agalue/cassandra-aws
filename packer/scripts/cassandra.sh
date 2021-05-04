#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

set -e

######### CUSTOMIZED VARIABLES #########

repo_version="311x"

########################################

echo "### Downloading and installing Cassandra $repo_version..."

cat <<EOF | sudo tee /etc/yum.repos.d/cassandra.repo
[cassandra]
name=Apache Cassandra
baseurl=https://www.apache.org/dist/cassandra/redhat/${repo_version}/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.apache.org/dist/cassandra/KEYS
EOF

sudo yum install -y java-1.8.0-openjdk-devel
sudo yum install -y cassandra cassandra-tools

echo  "### Downloading and installing Cassandra Reaper..."

curl -1sLf \
  'https://dl.cloudsmith.io/public/thelastpickle/reaper/setup.rpm.sh' \
  | sudo -E bash
sudo yum install -y reaper

echo  "### Creating reaper config using Cassandra as backend..."

cat <<EOF | sudo tee /etc/cassandra-reaper/cassandra-reaper.yaml
segmentCountPerNode: 64
repairParallelism: SEQUENTIAL
repairIntensity: 0.7
scheduleDaysBetween: 7
repairRunThreadCount: 15
hangingRepairTimeoutMins: 30
storageType: cassandra
enableCrossOrigin: true
incrementalRepair: false
blacklistTwcsTables: false
enableDynamicSeedList: true
repairManagerSchedulingIntervalSeconds: 10
jmxConnectionTimeoutInSeconds: 5
useAddressTranslator: false
maxParallelRepairs: 10
purgeRecordsAfterInDays: 30
numberOfRunsToKeepPerUnit: 10
datacenterAvailability: ALL
jmxAuth:
  username: cassandra
  password: cassandra
logging:
  level: INFO
  loggers:
    io.dropwizard: WARN
    org.eclipse.jetty: WARN
  appenders:
  - type: console
    logFormat: "%-6level [%d] [%t] %logger{5} - %msg %n"
    threshold: WARN
  - type: file
    logFormat: "%-6level [%d] [%t] %logger{5} - %msg %n"
    currentLogFilename: /var/log/cassandra-reaper/reaper.log
    archivedLogFilenamePattern: /var/log/cassandra-reaper/reaper-%d.log.gz
    archivedFileCount: 20
server:
  type: default
  applicationConnectors:
  - type: http
    port: 8080
    bindHost: 0.0.0.0
  adminConnectors:
  - type: http
    port: 8081
    bindHost: 0.0.0.0
  requestLog:
    appenders: []
cassandra:
  clusterName: "OpenNMS Cluster"
  contactPoints: ["127.0.0.1"]
  keyspace: reaper_db
autoScheduling:
  enabled: false
  initialDelayPeriod: PT15S
  periodBetweenPolls: PT10M
  timeBeforeFirstSchedule: PT5M
  scheduleSpreadPeriod: PT6H
metrics:
  frequency: 1 minute
  reporters:
    - type: log
      logger: metrics
accessControl:
  sessionTimeout: PT10M
  shiro:
    iniConfigs: ["classpath:shiro.ini"]
EOF

echo "### Done."
