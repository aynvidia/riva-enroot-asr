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

# BEGIN SCRIPT
check_enroot_version

# load config file
script_path="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
config_path="${script_path}/config_enroot.sh"
if [[ ! -f $config_path ]]; then
    echo 'Unable to load configuration file. Override path to file with -c argument.'
    exit 1
fi
source $config_path

echo "Shutting down Riva services..."

# Stop any running Riva processes more comprehensively
echo "Stopping Riva Speech services..."

# Kill start-riva processes
pkill -f "start-riva" &> /dev/null || true

# Kill enroot processes running riva containers
pkill -f "enroot.*riva-speech" &> /dev/null || true

# Kill any processes using the speech API port
if command -v lsof &> /dev/null; then
    lsof -ti:$riva_speech_api_port | xargs kill -9 &> /dev/null || true
fi

# Kill any processes using the HTTP API port  
if command -v lsof &> /dev/null; then
    lsof -ti:$riva_speech_api_http_port | xargs kill -9 &> /dev/null || true
fi

# Give processes time to shut down gracefully
sleep 3

echo "Riva services stopped."
