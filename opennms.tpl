#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

# AWS Template Variables

hostname=${hostname}
cassandra_server=${cassandra_server}
heap_size=${heap_size}
cache_max_entries=${cache_max_entries}
ring_buffer_size=${ring_buffer_size}
use_redis=${use_redis}

echo "### Configuring Hostname and Domain..."

hostnamectl set-hostname --static $hostname
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99_hostname.cfg

echo "### Configuring PostgreSQL..."

pg_version=`rpm -qa | grep 'postgres.*-server' | sed 's/.*server-//' | sed 's/-1PGDG.*//' | sed -e 's/\.[^.]*$//'`
pg_family=`echo $pg_version | sed 's/\.//'`

/usr/pgsql-$pg_version/bin/postgresql$pg_family-setup initdb

data_dir=/var/lib/pgsql/$pg_version/data
sed -r -i 's/(peer|ident)/trust/g' $data_dir/pg_hba.conf
sed -r -i "s/[#]?listen_addresses =.*/listen_addresses = '*'/" $data_dir/postgresql.conf

systemctl enable postgresql-$pg_version
systemctl start postgresql-$pg_version

if [[ "$use_redis" == "true" ]]; then
  echo "### Configuring Redis..."

  echo "vm.overcommit_memory=1" > /etc/sysctl.d/redis.conf
  sysctl -w vm.overcommit_memory=1
  redis_conf=/etc/redis.conf
  cp $redis_conf $redis_conf.bak
  sed -i -r "s/^bind .*/bind 0.0.0.0/" $redis_conf
  sed -i -r "s/^protected-mode .*/protected-mode no/" $redis_conf
  sed -i -r "s/^save /# save /" $redis_conf
  sed -i -r "s/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/" $redis_conf

  systemctl enable redis
  systemctl start redis
fi

echo "### Configuring OpenNMS..."

opennms_home=/opt/opennms
opennms_etc=$opennms_home/etc

# JVM Settings
# http://cloudurable.com/blog/cassandra_aws_system_memory_guidelines/index.html
# https://docs.datastax.com/en/dse/5.1/dse-admin/datastax_enterprise/operations/opsTuneJVM.html

jmxport=18980

num_of_cores=`cat /proc/cpuinfo | grep "^processor" | wc -l`
half_of_cores=`expr $num_of_cores / 2`

cat <<EOF > $opennms_etc/opennms.conf
START_TIMEOUT=0
JAVA_HEAP_SIZE=$heap_size
MAXIMUM_FILE_DESCRIPTORS=204800

ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -d64 -Djava.net.preferIPv4Stack=true"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+PrintGCTimeStamps -XX:+PrintGCDetails"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Xloggc:/opt/opennms/logs/gc.log"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseGCLogFileRotation"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:NumberOfGCLogFiles=10"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:GCLogFileSize=10M"

ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UnlockCommercialFeatures -XX:+FlightRecorder"

ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseStringDeduplication"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseG1GC"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:G1RSetUpdatingPauseTimePercent=5"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:MaxGCPauseMillis=500"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:InitiatingHeapOccupancyPercent=70"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:ParallelGCThreads=$half_of_cores"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:ConcGCThreads=$half_of_cores"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+ParallelRefProcEnabled"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+AlwaysPreTouch"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseTLAB"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+ResizeTLAB"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:-UseBiasedLocking"

# Configure Remote JMX
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.port=$jmxport"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.rmi.port=$jmxport"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.local.only=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.ssl=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.authenticate=true"

# Listen on all interfaces
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dopennms.poller.server.serverHost=0.0.0.0"

# Accept remote RMI connections on this interface
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Djava.rmi.server.hostname=$hostname"

# If you enable Flight Recorder, be aware of the implications since it is a commercial feature of the Oracle JVM.
#ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:StartFlightRecording=duration=600s,filename=opennms.jfr,delay=1h"
EOF

# JMX Groups
cat <<EOF > $opennms_etc/jmxremote.access
admin readwrite
jmx   readonly
EOF

# External Cassandra
# For 16 Cores, over 32GB of RAM, and a minimum of 16GB of ONMS Heap size on the OpenNMS server.
newts_cfg=$opennms_etc/opennms.properties.d/newts.properties
cat <<EOF > $newts_cfg
org.opennms.timeseries.strategy=newts
org.opennms.newts.config.hostname=$cassandra_server
org.opennms.newts.config.keyspace=newts
org.opennms.newts.config.port=9042
org.opennms.newts.query.minimum_step=30000
org.opennms.newts.query.heartbeat=45000
org.opennms.newts.config.ring_buffer_size=$ring_buffer_size
org.opennms.newts.config.cache.max_entries=$cache_max_entries
org.opennms.newts.config.writer_threads=$num_of_cores
org.opennms.newts.config.cache.priming.enable=true
org.opennms.newts.config.cache.priming.block_ms=-1
EOF
if [[ "$use_redis" == "true" ]]; then
  cat <<EOF >> $newts_cfg
org.opennms.newts.config.cache.strategy=org.opennms.netmgt.newts.support.RedisResourceMetadataCache
org.opennms.newts.config.cache.redis_hostname=127.0.0.1
org.opennms.newts.config.cache.redis_port=6379
EOF
fi

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

# WARNING: For testing purposes only
# Lab collection and polling interval (30 seconds)
sed -r -i 's/step="300"/step="30"/g' $opennms_etc/telemetryd-configuration.xml 
sed -r -i 's/interval="300000"/interval="30000"/g' $opennms_etc/collectd-configuration.xml 
sed -r -i 's/interval="300000" user/interval="30000" user/g' $opennms_etc/poller-configuration.xml 
sed -r -i 's/step="300"/step="30"/g' $opennms_etc/poller-configuration.xml 
files=(`ls -l $opennms_etc/*datacollection-config.xml | awk '{print $9}'`)
for f in "$${files[@]}"; do
  if [ -f $f ]; then
    sed -r -i 's/step="300"/step="30"/g' $f
  fi
done

# TODO: the following is due to some issues with the datachoices plugin
cat <<EOF > $opennms_etc/org.opennms.features.datachoices.cfg
enabled=false
acknowledged-by=admin
acknowledged-at=Mon Jan 01 00\:00\:00 EDT 2018
EOF

echo "### Running OpenNMS install script..."

$opennms_home/bin/runjava -S /usr/java/latest/bin/java
$opennms_home/bin/install -dis
