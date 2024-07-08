#!/usr/bin/env bash

set -eou pipefail

COMPOSITOR_VERSION="v0.2.0"
DOWNLOAD_URL="https://github.com/membraneframework/live_compositor/releases/download/$COMPOSITOR_VERSION/live_compositor_linux_x86_64.tar.gz"

export DEBIAN_FRONTEND=noninteractive
sleep 30
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y ffmpeg

if [[ "$ENABLE_GPU" -eq "1" ]]; then
  sudo apt-get install -y ubuntu-drivers-common
  sudo ubuntu-drivers install
fi

cd /home/ubuntu
curl -L $DOWNLOAD_URL -o live_compositor.tar.gz
tar -xf live_compositor.tar.gz
rm live_compositor.tar.gz

sudo cp /tmp/live-compositor.service /etc/systemd/system/live-compositor.service
sudo systemctl enable live-compositor.service
