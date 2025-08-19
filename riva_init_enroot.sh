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

enroot_import() {
    # Check if .sqsh file already exists
    sqsh_file="$(basename $1).sqsh"
    if [ -f "$sqsh_file" ]; then
        echo "  > Image file $sqsh_file already exists. Skipping import."
        return
    fi
    attempts=3
    echo "  > Importing $1 to enroot. This may take some time..."
    
    # Set up enroot credentials file for NGC authentication
    mkdir -p ~/.config/enroot
    echo "machine nvcr.io login \$oauthtoken password $NGC_API_KEY" > ~/.config/enroot/.credentials
    
    for ((i = 1 ; i <= $attempts ; i++)); do
        enroot import -o $(basename $1).sqsh docker://$1 &> /dev/null
        if [ $? -ne 0 ]; then
            echo "  > Attempt $i out of $attempts failed"
            if [ $i -eq $attempts ]; then
                echo "Error occurred importing '$1'."
                echo "  > Trying with verbose output to see the error:"
                enroot import -o $(basename $1).sqsh docker://$1
                echo "Exiting."
                exit 1
            else
                echo "  > Trying again..."
                continue
            fi
        else
            break
        fi
    done
}

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
if [ -z "$1" ]; then
    config_path="${script_path}/config_enroot.sh"
else
    config_path=$(readlink -f $1)
fi

if [[ ! -f $config_path ]]; then
    echo 'Unable to load configuration file. Override path to file with -c argument.'
    exit 1
fi
source $config_path || exit 1

# Ensure at least one language is selected for ASR
if [[ "$service_enabled_asr" = true ]] && [[ "${#asr_language_code[@]}" = 0 ]]; then
    echo "Error: please select a ASR language"
    exit 1
fi

# Ensure at least one language is selected for TTS
if [[ "$service_enabled_tts" = true ]] && [[ "${#tts_language_code[@]}" = 0 ]]; then
    echo "Error: please select a TTS language"
    exit 1
fi

# NLP not supported for languages other than English
if [ "$service_enabled_nlp" = true ]; then
    if [[ ! "${asr_language_code[@]}" =~ "en-US" ]]; then
        echo "Error: NLP not supported for languages other than English"
        exit 1
    fi
    if [[ "${asr_language_code[@]}" =~ "en-US" ]] && [[ "${#asr_language_code[@]}" > 1 ]]; then
        echo "Warning: NLP not supported for languages other than English"
    fi
fi

# automatically get NGC_API_KEY or request from user if necessary
NGC_API_KEY="$(get_ngc_key_from_environment)"
if [ -z "$NGC_API_KEY" ]; then
    read -sp 'Please enter API key for ngc.nvidia.com: ' NGC_API_KEY
    echo
fi

# Note: enroot doesn't require explicit login like Docker, 
# but we'll validate the key by attempting to import an image
echo "Preparing to import required container images..."
echo "Note: This may take some time, depending on the speed of your Internet connection."

# import all the requisite images we're going to need
# import the speech server if any of asr/nlp/tts/nmt services are requested
if [ "$service_enabled_asr" = true ] || [ "$service_enabled_nlp" = true ] || [ "$service_enabled_tts" = true ] || [ "$service_enabled_nmt" = true ]; then
    echo "> Importing Riva Speech Server images."
    enroot_import $image_speech_api
fi

if [ "$use_existing_rmirs" = false ]; then
    echo
    echo "Downloading models (RMIRs) from NGC..."
    echo "Note: this may take some time, depending on the speed of your Internet connection."
    echo "To skip this process and use existing RMIRs set the location and corresponding flag in config.sh."
    
    # Create model repository directory if it doesn't exist
    mkdir -p "$riva_model_loc"

    # build up commands to download from NGC
    if [ "$service_enabled_asr" = true ] || [ "$service_enabled_nlp" = true ] || [ "$service_enabled_tts" = true ] || [ "$service_enabled_nmt" = true ]; then
        gmr_speech_models=""
        if [ "$service_enabled_asr" = true ]; then
            for model in ${models_asr[@]}; do
                gmr_speech_models+=" $model"
            done
        fi
        if [ "$service_enabled_nlp" = true ]; then
            for model in ${models_nlp[@]}; do
                gmr_speech_models+=" $model"
            done
        fi
        if [ "$service_enabled_tts" = true ]; then
            for model in ${models_tts[@]}; do
                gmr_speech_models+=" $model"
            done
        fi
        if [ "$service_enabled_nmt" = true ]; then
            for model in ${models_nmt[@]}; do
                gmr_speech_models+=" $model"
            done
        fi

        # Create container name for model download
        download_container="riva-models-download"
        
        # download required models
        if [[ $riva_target_gpu_family == "tegra" ]]; then
            enroot start \
              --root \
              --rw \
              --mount $riva_model_loc:/data \
              --env "NGC_CLI_API_KEY=$NGC_API_KEY" \
              --env "NGC_CLI_ORG=$riva_ngc_org" \
              --env "gmr_speech_models_ngc=$gmr_speech_models" \
              $(basename $image_speech_api) \
              bash -c 'cd /usr/local/bin; wget --no-verbose https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/3.48.0/files/ngccli_arm64.zip; \
              unzip -qo ngccli_arm64.zip; chmod u+x ngc-cli/ngc; rm -f ngccli_arm64.zip; mv ngc-cli/* .; cd -; \
              rm -rf /tmp/artifacts; mkdir -p /tmp/artifacts; cd /tmp/artifacts; echo; \
              for model in $(echo $gmr_speech_models_ngc | tr " " "\n"); do ngc registry model download-version $model; done; \
              rm -rf /data/models; mkdir -p /data/prebuilt /data/rmir; \
              for file in /tmp/artifacts/*/*.rmir; do mv $file /data/rmir/ &> /dev/null; done; \
              for file in /tmp/artifacts/*/*.tar.gz; do mv $file /data/prebuilt/ &> /dev/null; done; \
              if [ -z "$(ls -A /data/rmir)" ]; then rm -rf /data/rmir; fi; \
              if [ -z "$(ls -A /data/prebuilt)" ]; then rm -rf /data/prebuilt; fi'
        else
            enroot start \
              --root \
              --rw \
              --mount $riva_model_loc:/data \
              --env "NGC_CLI_API_KEY=$NGC_API_KEY" \
              --env "NGC_CLI_ORG=nvidia" \
              $(basename $image_speech_api).sqsh \
              download_ngc_models $gmr_speech_models
        fi

        if [ $? -ne 0 ]; then
            echo "Error in downloading models."
            exit 1
        fi
    fi
fi

# generate model repository
echo
set -x

# if rmirs are present, convert them to model repository
if [[ $riva_target_gpu_family != "tegra" ]] || ([[ $riva_target_gpu_family == "tegra" ]] && [ -d "$riva_model_loc/rmir" ]); then
    echo "Converting RMIRs at $riva_model_loc/rmir to Riva Model repository."
    enroot start \
      --root \
      --rw \
      --mount $riva_model_loc:/data \
      --env "MODEL_DEPLOY_KEY=${MODEL_DEPLOY_KEY}" \
      $(basename $image_speech_api).sqsh \
      deploy_all_models /data/rmir /data/models
      if [ $? -ne 0 ]; then
            echo "Error in deploying RMIR models."
            exit 1
      fi
fi

# if prebuilts are present, convert them to model repository
if [[ $riva_target_gpu_family == "tegra" ]] && [ -d "$riva_model_loc/prebuilt" ]; then
    echo "Converting prebuilts at $riva_model_loc/prebuilt to Riva Model repository."
    enroot start \
      --root \
      --rw \
      --mount $riva_model_loc:/data \
      $(basename $image_speech_api).sqsh \
      bash -c 'mkdir -p /data/models; \
      for file in /data/prebuilt/*.tar.gz; do tar xf $file -C /data/models/ &> /dev/null; done'
    if [ $? -ne 0 ]; then
            echo "Error in deploying prebuilt models."
            exit 1
    fi
fi

echo
echo "Riva initialization complete. Run ./riva_start_enroot.sh to launch services."
