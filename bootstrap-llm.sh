#!/usr/bin/env bash
set -euo pipefail

echo "=== IS-LLM bootstrap starting ==="

touch /root/.no_auto_tmux

EXPECTED_VLLM_VERSION="0.28.0"

MODEL="Black-Ink-Guild/Pernicious_Prophecy_70B_FP8"

VLLM_ARGS_VALUE="--host 127.0.0.1 --port 18000 --max-model-len 32768 --gpu-memory-utilization 0.90 --enable-auto-tool-choice --tool-call-parser llama3_json"

ACTUAL_VLLM_VERSION="$(vllm --version | awk '{print $NF}')"

if [ "$ACTUAL_VLLM_VERSION" != "$EXPECTED_VLLM_VERSION" ]; then
    echo "ERROR: Expected vLLM $EXPECTED_VLLM_VERSION, found $ACTUAL_VLLM_VERSION"
    exit 1
fi

echo "vLLM version: $ACTUAL_VLLM_VERSION"
echo "Model: $MODEL"

set_env_value() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" /etc/environment; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" /etc/environment
    else
        echo "${key}=\"${value}\"" >> /etc/environment
    fi
}

set_env_value "MODEL_NAME" "$MODEL"
set_env_value "VLLM_MODEL" "$MODEL"
set_env_value "VLLM_ARGS" "$VLLM_ARGS_VALUE"
set_env_value "AUTO_PARALLEL" "true"

echo
echo "Configured /etc/environment:"
grep -E '^(MODEL_NAME|VLLM_MODEL|VLLM_ARGS|AUTO_PARALLEL)=' /etc/environment

# Load the same values into this shell so Supervisor inherits them now,
# without requiring a reboot.
export MODEL_NAME="$MODEL"
export VLLM_MODEL="$MODEL"
export VLLM_ARGS="$VLLM_ARGS_VALUE"
export AUTO_PARALLEL="true"

if [ ! -f /etc/supervisor/conf.d/vllm.conf ]; then
    echo "ERROR: Vast vLLM Supervisor configuration not found."
    exit 1
fi

echo
echo "Restarting Vast-managed vLLM service..."

supervisorctl restart vllm

echo
echo "Waiting for vLLM on 127.0.0.1:18000..."

for i in $(seq 1 120); do
    if curl -fsS http://127.0.0.1:18000/v1/models >/tmp/is-vllm-models.json 2>/dev/null; then
        echo "vLLM is ready."
        break
    fi

    sleep 5
done

if ! curl -fsS http://127.0.0.1:18000/v1/models >/tmp/is-vllm-models.json; then
    echo "ERROR: vLLM failed to become healthy."
    supervisorctl status vllm || true
    exit 1
fi

echo
echo "=== IS-LLM bootstrap complete ==="

supervisorctl status vllm

echo
echo "Listeners:"
ss -ltnp | grep -E '18000|8000' || true

echo
echo "Loaded models:"
cat /tmp/is-vllm-models.json
echo
