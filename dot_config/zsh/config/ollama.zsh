#!/usr/bin/env zsh

# avoid memory contention
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_MAX_LOADED_MODELS=1

# quantize KV cache
export OLLAMA_KV_CACHE_TYPE=q8_0

# Maximum context length
export OLLAMA_CONTEXT_LENGTH=262144

# keep model loaded between requests
export OLLAMA_KEEP_ALIVE="30m"

# enable flash attention on Metal
export OLLAMA_FLASH_ATTENTION=1
