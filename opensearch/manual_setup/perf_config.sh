#!/bin/bash
# delete current data directory
rm -rf /var/lib/opensearch

# create the diretory again and give opensearch user ownership
mkdir  /var/lib/opensearch
chown opensearch:opensearch /var/lib/opensearch

# Calculate 50% ram of system
total_mem=$(free -m | awk '/^Mem:/{print $2}')
av_ram=$(($total_mem / 2))"m"

sed -i "s/-Xmx[0-9]\{1,\}g/-Xmx$av_ram/g; s/-Xms[0-9]\{1,\}g/-Xms$av_ram/g" /etc/opensearch/jvm.options

rm  /etc/security/limits.conf
echo "opensearch soft memlock unlimited" >> /etc/security/limits.conf
echo "opensearch hard memlock unlimited" >> /etc/security/limits.conf
echo "opensearch hard nofile 65536" >> /etc/security/limits.conf
echo "opensearch soft nofile 65536" >> /etc/security/limits.conf

sed -i "s/#OPENSEARCH_JAVA_OPTS=/OPENSEARCH_JAVA_OPTS=\"-Xms${av_ram} -Xmx${av_ram}\"/g" /etc/sysconfig/opensearch
sed -i "s/#MAX_LOCKED_MEMORY=unlimited/MAX_LOCKED_MEMORY=unlimited/g" /etc/sysconfig/opensearch

# Check if the LimitMEMLOCK setting is already present in opensearch.service
if grep -q "LimitMEMLOCK" "/usr/lib/systemd/system/opensearch.service"; then
  echo "LimitMEMLOCK already set"
else
  # Append the LimitMEMLOCK setting to opensearch.service
  echo -e "[Service]\nLimitMEMLOCK=infinity" >> /usr/lib/systemd/system/opensearch.service
  echo "LimitMEMLOCK set to infinity"
fi

systemctl daemon-reload