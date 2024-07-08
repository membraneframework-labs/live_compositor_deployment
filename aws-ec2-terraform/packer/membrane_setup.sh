#!/usr/bin/env bash

set -eou pipefail

export DEBIAN_FRONTEND=noninteractive
sleep 30
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y ffmpeg elixir erlang build-essential

if [[ "$ENABLE_GPU" -eq "1" ]]; then
  sudo apt-get install -y ubuntu-drivers-common
  sudo ubuntu-drivers install
fi

cd /home/ubuntu/project
mix local.hex --force
mix local.rebar --force
mix deps.get
MIX_ENV=prod mix release

sudo cp /tmp/live-compositor.service /etc/systemd/system/live-compositor.service
sudo systemctl enable live-compositor.service

