#!/usr/bin/env bash
set -euo pipefail

echo "=== IS-VIDEO bootstrap starting ==="

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

COMFY_DIR="/workspace/ComfyUI"
VIDEO_DIR="/workspace/is-server/video"

COMFY_COMMIT="b1693ecba9f5b65f8c80ab36b195ab963ec92413"

MANAGER_REPO="https://github.com/Comfy-Org/ComfyUI-Manager"
MANAGER_COMMIT="fe1193c0c8168904e32d814190ba7f2ba2ad7581"

MINIMAX_TURBO_REPO="https://github.com/Larryvrh/ComfyUI-MiniMax-H3-Turbo.git"
MINIMAX_TURBO_COMMIT="4274783a23afcfdbea3b4876cb79effd6c510785"

API_CONVERTER_REPO="https://github.com/SethRobinson/comfyui-workflow-to-api-converter-endpoint"
API_CONVERTER_COMMIT="bc8538278f82053b3ca10a44d62d02596f8e1a37"

WORKFLOW_NAME="video_minimax_h3_r2v.json"

# Disable Vast auto-tmux.
touch /root/.no_auto_tmux


# ---------------------------------------------------------------------------
# Verify ComfyUI exists
# ---------------------------------------------------------------------------

if [ ! -d "$COMFY_DIR/.git" ]; then
    echo "ERROR: ComfyUI repository not found at:"
    echo "  $COMFY_DIR"
    exit 1
fi

echo
echo "ComfyUI commit:"
echo "  $COMFY_COMMIT"


# ---------------------------------------------------------------------------
# Stop ComfyUI before changing the environment
# ---------------------------------------------------------------------------

echo
echo "Stopping ComfyUI..."

supervisorctl stop comfyui >/dev/null 2>&1 || true

sleep 2


# ---------------------------------------------------------------------------
# Pin ComfyUI
# ---------------------------------------------------------------------------

echo
echo "Pinning ComfyUI..."

git -C "$COMFY_DIR" fetch origin "$COMFY_COMMIT"
git -C "$COMFY_DIR" checkout --detach "$COMFY_COMMIT"
git -C "$COMFY_DIR" reset --hard "$COMFY_COMMIT"


# ---------------------------------------------------------------------------
# Helper: install and pin a custom-node Git repository
# ---------------------------------------------------------------------------

install_git_node() {
    local name="$1"
    local repo="$2"
    local commit="$3"
    local path="$COMFY_DIR/custom_nodes/$name"

    echo
    echo "Custom node: $name"

    if [ ! -d "$path/.git" ]; then
        rm -rf "$path"
        git clone "$repo" "$path"
    fi

    git -C "$path" remote set-url origin "$repo"
    git -C "$path" fetch origin "$commit"
    git -C "$path" checkout --detach "$commit"
    git -C "$path" reset --hard "$commit"

    echo "Pinned:"
    git -C "$path" rev-parse HEAD
}


# ---------------------------------------------------------------------------
# Install known-good Git custom nodes
# ---------------------------------------------------------------------------

mkdir -p "$COMFY_DIR/custom_nodes"

install_git_node \
    "ComfyUI-Manager" \
    "$MANAGER_REPO" \
    "$MANAGER_COMMIT"

install_git_node \
    "ComfyUI-MiniMax-H3-Turbo" \
    "$MINIMAX_TURBO_REPO" \
    "$MINIMAX_TURBO_COMMIT"

install_git_node \
    "comfyui-workflow-to-api-converter-endpoint" \
    "$API_CONVERTER_REPO" \
    "$API_CONVERTER_COMMIT"


# ---------------------------------------------------------------------------
# Install IS custom nodes
# ---------------------------------------------------------------------------

install_is_node() {
    local name="$1"
    local src="$VIDEO_DIR/custom_nodes/$name/__init__.py"
    local dst="$COMFY_DIR/custom_nodes/$name"

    echo "Installing IS custom node: $name"

    if [ ! -f "$src" ]; then
        echo "ERROR: IS custom node source not found:"
        echo "  $src"
        exit 1
    fi

    mkdir -p "$dst"
    cp "$src" "$dst/__init__.py"
}

echo
echo "Installing IS custom nodes..."

install_is_node "IS_Continuation"
install_is_node "IS_ClipLength"
install_is_node "IS_Resolution16x9"


# ---------------------------------------------------------------------------
# Create required model/workflow directories
# ---------------------------------------------------------------------------

mkdir -p \
    "$COMFY_DIR/models/vae" \
    "$COMFY_DIR/models/text_encoders" \
    "$COMFY_DIR/models/diffusion_models" \
    "$COMFY_DIR/models/loras" \
    "$COMFY_DIR/user/default/workflows" \
    "$COMFY_DIR/input"


# ---------------------------------------------------------------------------
# Install known-good workflow
# ---------------------------------------------------------------------------

echo
echo "Installing known-good workflow..."

if [ ! -f "$VIDEO_DIR/$WORKFLOW_NAME" ]; then
    echo "ERROR: Workflow not found:"
    echo "  $VIDEO_DIR/$WORKFLOW_NAME"
    exit 1
fi

cp \
    "$VIDEO_DIR/$WORKFLOW_NAME" \
    "$COMFY_DIR/user/default/workflows/$WORKFLOW_NAME"


# ---------------------------------------------------------------------------
# Model download helper
# ---------------------------------------------------------------------------

download_if_missing() {
    local path="$1"
    local url="$2"

    if [ -s "$path" ]; then
        echo "Exists: $path"
    else
        echo "Downloading: $path"
        wget -c -O "$path" "$url"
    fi
}


# ---------------------------------------------------------------------------
# MiniMax H3 models
# ---------------------------------------------------------------------------

download_if_missing \
    "$COMFY_DIR/models/vae/minimax_h3_video_vae_fp16.safetensors" \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors?download=true"

download_if_missing \
    "$COMFY_DIR/models/vae/minimax_h3_audio_vae_fp32.safetensors" \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors?download=true"

download_if_missing \
    "$COMFY_DIR/models/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors" \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors?download=true"

download_if_missing \
    "$COMFY_DIR/models/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors" \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors?download=true"

download_if_missing \
    "$COMFY_DIR/models/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors" \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors?download=true"


# Optional Blackwell-optimized NVFP4 Ref2VA base.
download_if_missing \
    "$COMFY_DIR/models/diffusion_models/minimax_h3_ref2va_pruned_nvfp4.safetensors" \
    "https://huggingface.co/lilcheaty/MiniMax-H3-NVFP4/resolve/main/minimax_h3_ref2va_pruned_nvfp4.safetensors?download=true"

# Higher-resolution REF2VA Turbo profile.
download_if_missing \
    "$COMFY_DIR/models/loras/minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors" \
    "https://huggingface.co/lightx2v/Minimax-h3-Turbo/resolve/main/minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors?download=true"


# ---------------------------------------------------------------------------
# Install ComfyUI Python requirements
# ---------------------------------------------------------------------------

echo
echo "Installing ComfyUI requirements..."

if [ -x /venv/main/bin/python ]; then
    /venv/main/bin/python -m pip install \
        -r "$COMFY_DIR/requirements.txt"
else
    python -m pip install \
        -r "$COMFY_DIR/requirements.txt"
fi


# ---------------------------------------------------------------------------
# Install known-good Supervisor configuration
# ---------------------------------------------------------------------------

echo
echo "Installing Supervisor configuration..."

if [ ! -f "$VIDEO_DIR/comfyui.conf" ]; then
    echo "ERROR: Supervisor config not found:"
    echo "  $VIDEO_DIR/comfyui.conf"
    exit 1
fi

cp \
    "$VIDEO_DIR/comfyui.conf" \
    /etc/supervisor/conf.d/comfyui.conf

supervisorctl reread
supervisorctl update


# ---------------------------------------------------------------------------
# Start ComfyUI
# ---------------------------------------------------------------------------

echo
echo "Starting ComfyUI..."

supervisorctl start comfyui


# ---------------------------------------------------------------------------
# Wait for API
# ---------------------------------------------------------------------------

echo
echo "Waiting for ComfyUI on 127.0.0.1:18188..."

READY="false"

for i in $(seq 1 120); do
    if curl -fsS \
        http://127.0.0.1:18188/system_stats \
        >/tmp/is-comfy-system-stats.json \
        2>/dev/null
    then
        READY="true"
        break
    fi

    if supervisorctl status comfyui 2>/dev/null \
        | grep -qE 'EXITED|FATAL'
    then
        echo
        echo "ComfyUI exited while starting."
        break
    fi

    if [ $((i % 10)) -eq 0 ]; then
        echo "Still waiting... $((i * 2)) seconds"
    fi

    sleep 2
done


# ---------------------------------------------------------------------------
# Failure diagnostics
# ---------------------------------------------------------------------------

if [ "$READY" != "true" ]; then
    echo
    echo "ERROR: ComfyUI failed to become healthy."

    echo
    echo "Supervisor:"
    supervisorctl status comfyui || true

    echo
    echo "Processes:"
    ps aux | grep -E '[p]ython.*main.py|[c]omfy' || true

    echo
    echo "Listeners:"
    ss -ltnp | grep 18188 || true

    echo
    echo "GPU:"
    nvidia-smi || true

    echo
    echo "Last ComfyUI log lines:"
    tail -n 100 /var/log/portal/comfyui.log || true

    exit 1
fi


# ---------------------------------------------------------------------------
# Success summary
# ---------------------------------------------------------------------------

echo
echo "=== IS-VIDEO bootstrap complete ==="

echo
echo "ComfyUI:"
git -C "$COMFY_DIR" rev-parse HEAD

echo
echo "Custom nodes:"

printf "ComfyUI-Manager: "
git -C \
    "$COMFY_DIR/custom_nodes/ComfyUI-Manager" \
    rev-parse HEAD

printf "ComfyUI-MiniMax-H3-Turbo: "
git -C \
    "$COMFY_DIR/custom_nodes/ComfyUI-MiniMax-H3-Turbo" \
    rev-parse HEAD

printf "comfyui-workflow-to-api-converter-endpoint: "
git -C \
    "$COMFY_DIR/custom_nodes/comfyui-workflow-to-api-converter-endpoint" \
    rev-parse HEAD

echo
echo "IS custom nodes:"
ls -l \
    "$COMFY_DIR/custom_nodes/IS_Continuation/__init__.py" \
    "$COMFY_DIR/custom_nodes/IS_ClipLength/__init__.py" \
    "$COMFY_DIR/custom_nodes/IS_Resolution16x9/__init__.py"

echo
echo "Service:"
supervisorctl status comfyui

echo
echo "Listener:"
ss -ltnp | grep 18188 || true

echo
echo "Workflow:"
echo "  $COMFY_DIR/user/default/workflows/$WORKFLOW_NAME"

echo
echo "Models:"

find \
    "$COMFY_DIR/models" \
    -maxdepth 2 \
    -type f \
    | grep -E 'minimax_h3|qwen3vl' \
    | sort
