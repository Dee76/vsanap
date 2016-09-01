#!/bin/bash

# Check to see if we're running under Photon. If not, exit.
echo -e "Checking for Photon . . ."
if uname -a | grep -iq photon; then
  echo -e " - Photon detected, continuing build . . ."
else
  echo -e " - Photon not detected, exiting . . ."
  echo -e "Done.\n"
  exit
fi

# Variables
defaultPW="VMw@re1!" # The default pw used for the various components.
ip=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1) # Grab the IP address of eth0.

# Host folder structure for VSANAP:
#
# /opt/vsanap :: Root folder for vsanap
# /opt/vsanap/grafana :: Contains vsanap grafana config files
# /opt/vsanap/snap :: Contains vsanap snap config files and plugins
# /opt/vsanap/influxdb :: Contains vsanap influxdb config files
# /opt/vsanap/vsanapper :: Contains vsanapper python program for querying VSAN

# Start and enable Docker.
echo -e "\nStarting and enabling Docker . . ."

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
echo -e "\nRetrieving InfluxDB configuration file . . .\n"
curl -s -o /opt/vsanap/influxdb/influxdb.conf https://raw.githubusercontent.com/Dee76/vsanap/master/influxdb/influxdb.conf
echo -e "\nRunning InfluxDB Docker container . . .\n"
docker run -d -p 8083:8083 -p 8086:8086 \
  --name vsanap_influxdb \
  -v /opt/vsanap/influxdb:/etc/influxdb:ro \
  influxdb -config /etc/influxdb/influxdb.conf

# Run Python container for vsanapper.
echo -e "\nRetrieving VSANAPper . . .\n"
# curl -s -o /opt/vsanap/vsanapper/vsanapper.py https://raw.githubusercontent.com/Dee76/vsanap/master/vsanapper/vsanapper.py
echo -e "\nRetrieving Python Docker container . . .\n"
docker pull python

# Executable for Snap to run, which will execute VSANAPper to get stats from VSAN
#docker run -it --rm --name vsanap_vsanapper -v /opt/vsanap/vsanapper:/usr/src/myapp -w /usr/src/myapp python:3 python vsanapper.py

# Run Snap Docker container.
echo -e "\nRunning a Snap Docker container . . .\n"
docker run -d -p 8181:8181 \
  --name vsanap_snap \
  -v /opt/vsanap/snap:/opt/snap \
  edyesed/intelsdi-snap

# Run Grafana Docker container on port 3000 with the default password, and mounting grafana config volume.
echo -e "\nRunning a Grafana Docker container . . .\n"
docker run -d -p 3000:3000 \
  --name vsanap_grafana \
  -v /opt/vsanap/grafana:/opt/grafana \
  -e "GF_SERVER_ROOT_URL=http://$ip" \
  -e "GF_SECURITY_ADMIN_PASSWORD=$defaultPW" \
  grafana/grafana

echo -e "\nAccess VSANAP on http://$ip:3000 with admin password of $defaultPW"
echo -e "Done.\n"
exit
