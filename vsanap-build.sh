#!/bin/bash

# Check to see if we're running under Photon. If not, exit.
if uname -a | grep -iq photon; then
  echo -e "Photon detected, continuing build . . .\n"
else
  echo -e "Photon not detected, exiting . . .\n"
  exit
fi

# Variables
defaultPW="VMw@re1!" # The default pw used for the various components.
ip=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1) # Grab the IP address of eth0.

# Host folder structure that supports VSANAP:
#
# /opt/vsanap :: Root folder for vsanap
# /opt/vsanap/grafana :: Contains vsanap grafana config files
# /opt/vsanap/snap :: Contains vsanap snap config files and plugins
# /opt/vsanap/influxdb :: Contains vsanap influxdb config files

# Start and enable Docker.
echo -e "Starting and enabling Docker . . ."

if systemctl status docker | grep -iq 'Active: active (running)'; then
  echo -e " - Docker is already started . . ."
else
  echo -e " - Starting Docker . . ."
  systemctl start docker
fi
if systemctl status docker | grep -iq 'Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled;'; then
  echo -e " - Docker is already enabled . . ."
else
  echo -e " - Enabling Docker . . ."
  systemctl enable docker
fi

# Run InfluxDB container ...
echo -e "Running InfluxDB Docker container . . .\n"
docker run -d -p 8083:8083 -p 8086:8086 \
  -v /opt/vsanap/influxdb/influxdb.conf:/etc/influxdb/influxdb.conf:ro \
  influxdb -config /etc/influxdb/influxdb.conf

# Run Grafana Docker container on port 3000 with the default password, and mounting grafana config volume.
echo -e "Running a Grafana Docker container . . .\n"
docker run -d -p 3000:3000 \
  -v /opt/vsanap/grafana:/opt/grafana \
  -e "GF_SERVER_ROOT_URL=http://$ip" \
  -e "GF_SECURITY_ADMIN_PASSWORD=$defaultPW" \
  grafana/grafana

echo -e "\nAccess VSANAP on http://$ip:3000 with admin password of $defaultPW"
echo -e "Done.\n"
exit
