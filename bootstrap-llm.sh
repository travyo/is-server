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


# ---------------------------------------------------------------------------
# Persist Vast vLLM configuration
# ---------------------------------------------------------------------------

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

grep -E \
    '^(MODEL_NAME|VLLM_MODEL|VLLM_ARGS|AUTO_PARALLEL)=' \
    /etc/environment


# ---------------------------------------------------------------------------
# Make configuration available to this shell / Supervisor start
# ---------------------------------------------------------------------------

export MODEL_NAME="$MODEL"
export VLLM_MODEL="$MODEL"
export VLLM_ARGS="$VLLM_ARGS_VALUE"
export AUTO_PARALLEL="true"


# ---------------------------------------------------------------------------
# Verify Vast Supervisor configuration exists
# ---------------------------------------------------------------------------

if [ ! -f /etc/supervisor/conf.d/vllm.conf ]; then
    echo "ERROR: Vast vLLM Supervisor configuration not found."
    exit 1
fi


# ---------------------------------------------------------------------------
# Completely stop any previous vLLM instance
# ---------------------------------------------------------------------------

echo
echo "Stopping existing vLLM service..."

supervisorctl stop vllm >/dev/null 2>&1 || true

sleep 3


# ---------------------------------------------------------------------------
# Kill orphaned vLLM processes
#
# Vast launches vLLM through pty/unbuffer and it is possible for the
# underlying API/EngineCore processes to survive a Supervisor restart.
# ---------------------------------------------------------------------------

kill_matching_processes() {
    local pattern="$1"
    local signal="$2"

    mapfile -t pids < <(
        pgrep -f "$pattern" 2>/dev/null || true
    )

    if [ "${#pids[@]}" -eq 0 ]; then
        return
    fi

    for pid in "${pids[@]}"; do
        # Never signal this bootstrap process itself.
        if [ "$pid" = "$$" ]; then
            continue
        fi

        echo "Sending $signal to PID $pid matching: $pattern"
        kill "-$signal" "$pid" 2>/dev/null || true
    done
}

echo
echo "Checking for stale vLLM processes..."

kill_matching_processes \
    "/usr/local/bin/vllm serve" \
    "TERM"

kill_matching_processes \
    "VLLM::EngineCore" \
    "TERM"

sleep 8


# ---------------------------------------------------------------------------
# Escalate if anything survived
# ---------------------------------------------------------------------------

if pgrep -f "/usr/local/bin/vllm serve" >/dev/null 2>&1 || \
   pgrep -f "VLLM::EngineCore" >/dev/null 2>&1
then
    echo
    echo "Stale vLLM process still detected; escalating to SIGKILL..."

    kill_matching_processes \
        "/usr/local/bin/vllm serve" \
        "KILL"

    kill_matching_processes \
        "VLLM::EngineCore" \
        "KILL"

    sleep 3
fi


# ---------------------------------------------------------------------------
# Make sure port 18000 is free
# ---------------------------------------------------------------------------

if ss -ltnp | grep -q '127.0.0.1:18000'; then
    echo
    echo "ERROR: Port 18000 is still in use:"
    ss -ltnp | grep 18000 || true
    exit 1
fi


# ---------------------------------------------------------------------------
# Diagnostic GPU state before restart
# ---------------------------------------------------------------------------

echo
echo "GPU state before vLLM start:"
nvidia-smi || true


# ---------------------------------------------------------------------------
# Start clean vLLM service
# ---------------------------------------------------------------------------

echo
echo "Starting Vast-managed vLLM service..."

supervisorctl start vllm


# ---------------------------------------------------------------------------
# Wait for API
# ---------------------------------------------------------------------------

echo
echo "Waiting for vLLM on 127.0.0.1:18000..."

READY="false"

for i in $(seq 1 180); do
    if curl -fsS \
        http://127.0.0.1:18000/v1/models \
        >/tmp/is-vllm-models.json \
        2>/dev/null
    then
        READY="true"
        break
    fi

    # Fail early if Supervisor already knows the service died.
    if supervisorctl status vllm 2>/dev/null | grep -qE 'EXITED|FATAL'; then
        echo
        echo "vLLM service exited while starting."
        break
    fi

    if [ $((i % 12)) -eq 0 ]; then
        echo "Still waiting... $((i * 5)) seconds"
    fi

    sleep 5
done


# ---------------------------------------------------------------------------
# Failure diagnostics
# ---------------------------------------------------------------------------

if [ "$READY" != "true" ]; then
    echo
    echo "ERROR: vLLM failed to become healthy."

    echo
    echo "Supervisor:"
    supervisorctl status vllm || true

    echo
    echo "Processes:"
    ps aux | grep -E '[v]llm|EngineCore' || true

    echo
    echo "Listeners:"
    ss -ltnp | grep -E '18000|8000' || true

    echo
    echo "GPU:"
    nvidia-smi || true

    echo
    echo "Last vLLM log lines:"
    tail -n 80 /var/log/portal/vllm.log || true

    exit 1
fi


# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------

echo
echo "=== IS-LLM bootstrap complete ==="

echo
echo "Supervisor:"
supervisorctl status vllm

echo
echo "Listeners:"
ss -ltnp | grep -E '18000|8000' || true

echo
echo "Loaded models:"
cat /tmp/is-vllm-models.json
echo
