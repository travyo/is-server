#!/usr/bin/env bash
set -euo pipefail

MODEL="Black-Ink-Guild/Pernicious_Prophecy_70B_FP8"

LOG_DIR="/workspace/llm/logs"
LOG_FILE="$LOG_DIR/pernicious-startup.log"

HF_DIR="/workspace/llm/hf_home"

mkdir -p "$LOG_DIR"
mkdir -p "$HF_DIR/hub"

export HF_HOME="$HF_DIR"
export HUGGINGFACE_HUB_CACHE="$HF_DIR/hub"

# Required on our Blackwell/vLLM 0.28 setup because FlashInfer sampling
# failed during warmup.
export VLLM_USE_FLASHINFER_SAMPLER=0

# Log to both terminal and persistent file.
exec > >(tee -a "$LOG_FILE") 2>&1

echo
echo "============================================================"
echo "Starting Pernicious Prophecy"
echo "Time:  $(date)"
echo "Model: $MODEL"
echo "============================================================"

exec /opt/vllm-venv/bin/vllm serve \
  "$MODEL" \
  --host 127.0.0.1 \
  --port 8000 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --enable-auto-tool-choice \
  --tool-call-parser llama3_json
