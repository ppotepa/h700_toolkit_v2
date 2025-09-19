#!/bin/bash

# Install dependencies

echo "Installing dependencies..."

# For Ubuntu/Debian
sudo apt update
sudo apt install -y git make pv ddrescue util-linux e2fsprogs fzf whiptail jq

# For abootimg, may need to build or install
echo "Please install abootimg and mkbootimg manually if not available."
