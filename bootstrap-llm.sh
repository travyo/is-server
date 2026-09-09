#!/usr/bin/env bash
set -euo pipefail

echo "=== IS-LLM bootstrap starting ==="

EXPECTED_VLLM_VERSION="0.28.0"

ACTUAL_VLLM_VERSION="$(vllm --version | awk '{print $NF}')"

if [ "$ACTUAL_VLLM_VERSION" != "$EXPECTED_VLLM_VERSION" ]; then
  echo "ERROR: Expected vLLM $EXPECTED_VLLM_VERSION, found $ACTUAL_VLLM_VERSION"
  exit 1
fi

if [ ! -f /etc/supervisor/conf.d/vllm.conf ]; then
  echo "ERROR: Vast vLLM Supervisor configuration not found."
  exit 1
fi

echo "vLLM version: $ACTUAL_VLLM_VERSION"
echo "Using Vast-managed vLLM service."

if supervisorctl status vllm | grep -q RUNNING; then
  echo "vLLM is already running; leaving it alone."
else
  echo "Starting vLLM..."
  supervisorctl start vllm
fi

echo
echo "=== IS-LLM bootstrap complete ==="
echo "Status:"
supervisorctl status vllm
