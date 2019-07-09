#!/bin/bash
# Author: Alejandro Galue <agalue@opennms.org>

# AWS Template Variables

hostname=${hostname}
cassandra_server=${cassandra_server}
cassandra_rf=${cassandra_rf}
cassandra_dc=${cassandra_dc}
heap_size=${heap_size}
cache_max_entries=${cache_max_entries}
ring_buffer_size=${ring_buffer_size}
use_redis=${use_redis}

echo "### Configuring Hostname and Domain..."

hostnamectl set-hostname --static $hostname
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99_hostname.cfg

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

num_of_cores=`cat /proc/cpuinfo | grep "^processor" | wc -l`
half_of_cores=`expr $num_of_cores / 2`

sed -r -i "/JAVA_HEAP_SIZE/s/=.*/=$heap_size" $opennms_etc/opennms.conf
sed -r -i "/GCThreads/s/=.*/=$half_of_cores\"" $opennms_etc/opennms.conf
sed -r -i "/rmi.server.hostname/s/=.*/=$hostname\"" $opennms_etc/opennms.conf

# External Cassandra
# For 16 Cores, over 32GB of RAM, and a minimum of 16GB of ONMS Heap size on the OpenNMS server.
newts_cfg=$opennms_etc/opennms.properties.d/newts.properties
cat <<EOF > $newts_cfg
org.opennms.timeseries.strategy=newts
org.opennms.newts.config.hostname=$cassandra_server
org.opennms.newts.config.keyspace=newts
org.opennms.newts.config.port=9042
org.opennms.newts.config.ring_buffer_size=$ring_buffer_size
org.opennms.newts.config.cache.max_entries=$cache_max_entries
org.opennms.newts.config.writer_threads=$num_of_cores
org.opennms.newts.config.cache.priming.enable=true
org.opennms.newts.config.cache.priming.block_ms=-1
# For collecting data every 30 seconds from OpenNMS and Cassandra
org.opennms.newts.query.minimum_step=30000
org.opennms.newts.query.heartbeat=450000
EOF
if [[ "$use_redis" == "true" ]]; then
  cat <<EOF >> $newts_cfg
org.opennms.newts.config.cache.strategy=org.opennms.netmgt.newts.support.RedisResourceMetadataCache
org.opennms.newts.config.cache.redis_hostname=127.0.0.1
org.opennms.newts.config.cache.redis_port=6379
EOF
fi

# To monitor and collect metrics every 30 seconds from OpenNMS and Cassandra
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

echo "### Running OpenNMS install script..."

$opennms_home/bin/runjava -S /usr/java/latest/bin/java
$opennms_home/bin/install -dis

echo "### Waiting for Cassandra..."

until nodetool -h $cassandra_server status | grep $cassandra_server | grep -q "UN";
do
  sleep 10
done

echo "### Creating Newts keyspace..."

newts_cfg=$opennms_etc/newts.cql
sed -r -i "s/'DC1' : 2/'$cassandra_dc' : $cassandra_rf/" $newts_cfg
cqlsh -f $newts_cfg $cassandra_server

echo "### Starting OpenNMS..."

systemctl enable opennms
systemctl start opennms