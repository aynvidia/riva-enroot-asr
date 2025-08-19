#!/bin/bash
# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

# ENROOT VERSION - Modified to work with enroot instead of Docker

get_ngc_key_from_environment() {
    # first check the global NGC_API_KEY environment variable
    local ngc_key=$NGC_API_KEY
    # if env variable was not set, and a ~/.ngc/config exists
    # try to get it from there
    if [ -z "$ngc_key" ] && [[ -f "$HOME/.ngc/config" ]]
    then
        ngc_key=$(cat $HOME/.ngc/config | grep -m 1 -G "^\s*apikey\s*=.*" | sed 's/^\s*apikey\s*=\s*//g')
    fi
    echo $ngc_key
}

enroot_import_and_check() {
    image_name=$(basename $1)
    if enroot list | grep -q "^${image_name}$"; then
        echo "  > Image $image_name exists. Skipping import."
        return
    fi

    # confirm we have NGC access
    # automatically get NGC_API_KEY or request from user if necessary
    NGC_API_KEY="$(get_ngc_key_from_environment)"
    if [ -z "$NGC_API_KEY" ]; then
        read -sp 'Please enter API key for ngc.nvidia.com: ' NGC_API_KEY
        echo
    fi

    echo "  > Importing $1 to enroot. This may take some time..."
    
    # Set up enroot credentials file for NGC authentication
    mkdir -p ~/.config/enroot
    echo "machine nvcr.io login \$oauthtoken password $NGC_API_KEY" > ~/.config/enroot/.credentials
    
    enroot import -o ${image_name}.sqsh docker://$1 &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Error occurred importing '$1'."
        enroot import -o ${image_name}.sqsh docker://$1
        echo "Exiting."
        exit 1
    fi
}

script_path="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if [ -z "$1" ]; then
    config_path="${script_path}/config_enroot.sh"
else
    config_path=$(readlink -f $1)
fi

source $config_path

image_name=$(basename ${image_speech_api})
enroot_import_and_check ${image_speech_api}

# determine if TLS/SSL key & cert are provided
if [ -n "$ssl_cert" ]; then
    ssl_vol_args="--mount $ssl_cert:/ssl/server.crt"
else
    ssl_vol_args=""
fi

enroot start \
    --root \
    --rw \
    --mount /dev/bus/usb:/dev/bus/usb \
    --mount /dev/snd:/dev/snd \
    $ssl_vol_args \
    ${image_name}.sqsh
