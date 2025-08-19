#!/bin/bash
# Riva gRPC Streaming Test Script
# Tests various Riva gRPC services using built-in client tools

set -e

RIVA_SERVER=${RIVA_SERVER:-"localhost:50051"}
LANGUAGE=${LANGUAGE:-"en-US"}

echo "=============================="
echo "Riva gRPC Streaming Test Suite"
echo "=============================="
echo "Server: $RIVA_SERVER"
echo "Language: $LANGUAGE"
echo "=============================="

# Function to run commands inside Riva container
run_in_container() {
    enroot start --root riva-speech:2.18.0.sqsh "$@"
}

# Test 1: Health Check
echo ""
echo "🏥 Test 1: Health Check"
echo "----------------------"
if run_in_container grpc_health_probe -addr=$RIVA_SERVER; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Test 2: Simple ASR with audio file
echo ""
echo "🎤 Test 2: Simple ASR Recognition"
echo "--------------------------------"
if [ -f "sample_audio_prompt.wav" ]; then
    echo "Testing with sample_audio_prompt.wav..."
    run_in_container riva_asr_client \
        --server=$RIVA_SERVER \
        --language_code=$LANGUAGE \
        --audio_file=/userhome/home/aymaheshwari/enroot-riva/sample_audio_prompt.wav \
        --automatic_punctuation=true
    echo "✅ Simple ASR test completed"
else
    echo "⚠️  No sample audio file found, skipping simple ASR test"
fi

# Test 3: Streaming ASR (if audio file available)
echo ""
echo "🌊 Test 3: Streaming ASR"
echo "-----------------------"
if [ -f "sample_audio_prompt.wav" ]; then
    echo "Testing streaming ASR with sample_audio_prompt.wav..."
    run_in_container riva_streaming_asr_client \
        --server=$RIVA_SERVER \
        --language_code=$LANGUAGE \
        --audio_file=/userhome/home/aymaheshwari/enroot-riva/sample_audio_prompt.wav \
        --automatic_punctuation=true \
        --interim_results=true
    echo "✅ Streaming ASR test completed"
else
    echo "⚠️  No sample audio file found, skipping streaming ASR test"
fi

# Test 4: TTS (Text-to-Speech)
echo ""
echo "🗣️  Test 4: Text-to-Speech"
echo "-------------------------"
run_in_container riva_tts_client \
    --server=$RIVA_SERVER \
    --text="Hello, this is a test of Riva text to speech synthesis." \
    --output_file=/tmp/tts_output.wav \
    --language_code=$LANGUAGE
echo "✅ TTS test completed (output saved to /tmp/tts_output.wav)"

# Test 5: NLP Punctuation
echo ""
echo "📝 Test 5: NLP Punctuation"
echo "-------------------------"
echo "hello world how are you today this is a test" | run_in_container riva_nlp_punct \
    --server=$RIVA_SERVER \
    --language_code=$LANGUAGE
echo "✅ NLP punctuation test completed"

# Test 6: Interactive Streaming (optional)
echo ""
echo "🎙️  Test 6: Interactive Streaming"
echo "--------------------------------"
echo "Would you like to test real-time microphone streaming? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Starting interactive streaming ASR..."
    echo "Speak into your microphone. Press Ctrl+C to stop."
    run_in_container riva_streaming_asr_client \
        --server=$RIVA_SERVER \
        --language_code=$LANGUAGE \
        --automatic_punctuation=true \
        --interim_results=true \
        --mic
    echo "✅ Interactive streaming test completed"
else
    echo "⏭️  Skipping interactive streaming test"
fi

echo ""
echo "🎉 All Riva gRPC tests completed successfully!"
echo "=============================="

# Performance test (optional)
echo ""
echo "📊 Performance Test (Optional)"
echo "-----------------------------"
echo "Would you like to run a performance test with multiple concurrent requests? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Running performance test with 5 concurrent requests..."
    
    for i in {1..5}; do
        (
            echo "Worker $i starting..."
            run_in_container riva_asr_client \
                --server=$RIVA_SERVER \
                --language_code=$LANGUAGE \
                --audio_file=/userhome/home/aymaheshwari/enroot-riva/sample_audio_prompt.wav \
                --automatic_punctuation=true &> /tmp/perf_test_$i.log
            echo "Worker $i completed"
        ) &
    done
    
    wait
    echo "✅ Performance test completed. Check /tmp/perf_test_*.log for results"
fi

echo ""
echo "🏁 All tests finished!"
