#!/bin/bash
# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

# ENROOT VERSION - Modified to work with enroot instead of Docker

check_enroot_version() {
    if ! command -v enroot &> /dev/null; then
        echo "Unable to run enroot. Please check that enroot is installed and functioning."
        exit 1
    fi
    echo "Using enroot container runtime..."
}

delete_enroot_data() {
  # detect if local filesystem was used to store models
  if [ -d $1 ]; then
      read -r -p "Found models at '$1'. Delete? [y/N] " response
      if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
          sudo rm -rf $1
      else
          echo "Skipping..."
      fi
  else
      echo "'$1' directory not found or has already been deleted."
  fi
}

delete_enroot_image() {
  image_name=$(basename $1)
  sqsh_file="${image_name}.sqsh"
  
  # Check if .sqsh file exists
  if [ -f "$sqsh_file" ]; then
      read -r -p "Image file $sqsh_file found. Delete? [y/N] " response
      if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        rm -f "$sqsh_file"
        echo "Removed enroot image file: $sqsh_file"
      else
        echo "Skipping..."
      fi
  else
      echo "Image file $sqsh_file has not been imported, or has already been deleted."
  fi
}

# BEGIN SCRIPT
check_enroot_version

# load config file
script_path="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if [ -z "$1" ]; then
    config_path="${script_path}/config_enroot.sh"
else
    config_path=$(readlink -f $1)
fi
if [[ ! -f $config_path ]]; then
    echo 'Unable to load configuration file. Override path to file with -c argument.'
    exit 1
fi
source $config_path

echo "Cleaning up local Riva installation."

# First stop any running services
echo "Stopping any running Riva services..."
pkill -f "start-riva" &> /dev/null || true
pkill -f "enroot.*riva-speech" &> /dev/null || true

# Kill any processes using the API ports
if command -v lsof &> /dev/null; then
    lsof -ti:$riva_speech_api_port | xargs kill -9 &> /dev/null || true
    lsof -ti:$riva_speech_api_http_port | xargs kill -9 &> /dev/null || true
fi

sleep 3

# Clean up the base image
delete_enroot_image $image_speech_api

# Clean up model data
delete_enroot_data $riva_model_loc

echo "Cleanup complete."
