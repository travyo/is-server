#!/usr/bin/env bash
set -euo pipefail

echo "=== IS-LLM bootstrap starting ==="

# Disable Vast auto-tmux
touch /root/.no_auto_tmux

# Persistent directories
mkdir -p /workspace/llm/logs
mkdir -p /workspace/llm/hf_home/hub

# Copy known-good launcher into place
cp /workspace/is-server/llm/start-pernicious.sh /workspace/llm/start-pernicious.sh
chmod +x /workspace/llm/start-pernicious.sh

# Build disposable vLLM environment
if [ ! -x /opt/vllm-venv/bin/vllm ]; then
  echo "Installing vLLM environment..."
  rm -rf /opt/vllm-venv
  python3 -m venv /opt/vllm-venv
  /opt/vllm-venv/bin/python -m pip install -U pip
  /opt/vllm-venv/bin/pip install vllm==0.28.0
fi

# Install Supervisor service
cp /workspace/is-server/llm/is-llm.conf /etc/supervisor/conf.d/is-llm.conf

supervisorctl reread
supervisorctl update

echo "Starting IS-LLM..."
supervisorctl restart is-llm || supervisorctl start is-llm

echo
echo "=== IS-LLM bootstrap complete ==="
echo "Check status with:"
echo "  supervisorctl status is-llm"
echo
echo "Watch startup with:"
echo "  tail -f /workspace/llm/logs/pernicious-startup.log"
