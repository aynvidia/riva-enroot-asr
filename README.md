### Create this credentails
`cat ~/.config/enroot/.credentials `
> `machine nvcr.io login $oauthtoken password <NGC_API_KEY>`

## Use enroot to import docker
enroot import -o riva-speech:2.18.0.sqsh docker://nvcr.io\#nvidia/riva/riva-speech:2.18.0


## Riva Enroot Scripts

This directory contains enroot-compatible versions of all Riva scripts, allowing you to run Riva services using enroot instead of Docker.

## Files Created

### Core Scripts
- `riva_start_enroot.sh` - Start Riva services using enroot containers
- `riva_init_enroot.sh` - Initialize and download Riva models using enroot
- `riva_stop_enroot.sh` - Stop running Riva enroot containers
- `riva_clean_enroot.sh` - Clean up Riva enroot containers and data
- `riva_start_client_enroot.sh` - Start Riva client container using enroot

### ASR Language Model Tuning Scripts
- `asr_lm_tools/tune_LM_enroot.sh` - Tune language model hyperparameters for CPU/GPU decoders using enroot
- `asr_lm_tools/tune_LM_flashlight_enroot.sh` - Tune flashlight decoder hyperparameters using enroot

### Configuration
- `config_enroot.sh` - Configuration file adapted for enroot usage




## Usage

### 1. Configuration
Edit `config_enroot.sh` to match your requirements:
```bash
# Set your desired services
service_enabled_asr=true
service_enabled_nlp=true  
service_enabled_tts=true

# Configure model storage location
riva_model_loc="/path/to/your/model/storage"

# Set language codes
asr_language_code=("en-US")
tts_language_code=("en-US")
```

### 2. Initialize Riva
```bash
./riva_init_enroot.sh
```
This will:
- Import required container images from NGC
- Download and prepare model files
- Convert models to optimized format

### 3. Start Riva Services
```bash
./riva_start_enroot.sh
```
This will start the Riva speech services in an enroot container.

### 4. Stop Riva Services
```bash
./riva_stop_enroot.sh
```

### 5. Clean Up (Optional)
```bash
./riva_clean_enroot.sh
```
This will remove containers, images, and optionally model data.

## Troubleshooting

### Common Issues

1. **Enroot not found**
   - Ensure enroot is installed and in your PATH
   - Check enroot installation with `enroot --version`

2. **Image import failures**
   - Verify NGC API key is valid
   - Check network connectivity to nvcr.io
   - Ensure sufficient disk space for image storage

3. **Container start failures**
   - Check GPU availability and drivers
   - Verify model directory permissions
   - Review enroot configuration

4. **Port conflicts**
   - Default ports: 50051 (gRPC), 50000 (HTTP)
   - Modify `riva_speech_api_port` and `riva_speech_api_http_port` in config if needed

## Accessing the server

`curl -X GET http://localhost:50000/v1/health`

`curl -X POST http://localhost:50000/v1/audio/transcriptions \
  -F "file=@audio_file.wav" \
  -F "language=en-US"`

- Change language to hi-IN for hindi. 
 
## Changing supported language
 See config_enroot.sh for the list of supported languages for ASR
 - See following lines from Line 49 onwards
 `asr_language_code=("en-US, hi-IN")
# ASR acoustic model architecture
# Supported values for the model architecture are:
# conformer (all languages except em-ea), parakeet (en-US, em-ea, es-en-US), parakeet-rnnt (en-US only), whisper, distil_whisper, canary
asr_acoustic_model=("whisper")`