#!/usr/bin/env bash
set -euo pipefail

echo "=== IS-VIDEO bootstrap starting ==="

touch /root/.no_auto_tmux

COMFY_DIR="/workspace/ComfyUI"
REPO_DIR="/workspace/is-server"
VIDEO_DIR="$REPO_DIR/video"

COMFY_COMMIT="b1693ecba9f5b65f8c80ab36b195ab963ec92413"

MANAGER_COMMIT="fe1193c0c8168904e32d814190ba7f2ba2ad7581"
TURBO_COMMIT="4274783a23afcfdbea3b4876cb79effd6c510785"
API_CONVERTER_COMMIT="bc8538278f82053b3ca10a44d62d02596f8e1a37"

echo
echo "ComfyUI commit:"
echo "  $COMFY_COMMIT"

git config --global --add safe.directory "$COMFY_DIR" || true
git config --global --add safe.directory "$REPO_DIR" || true

if [ ! -d "$COMFY_DIR/.git" ]; then
    echo "ERROR: $COMFY_DIR is not a Git repository."
    exit 1
fi


# ---------------------------------------------------------------------------
# Stop Comfy while changing the installation
# ---------------------------------------------------------------------------

echo
echo "Stopping ComfyUI..."

supervisorctl stop comfyui >/dev/null 2>&1 || true


# ---------------------------------------------------------------------------
# Pin ComfyUI
# ---------------------------------------------------------------------------

echo
echo "Pinning ComfyUI..."

git -C "$COMFY_DIR" fetch origin "$COMFY_COMMIT"
git -C "$COMFY_DIR" checkout --detach "$COMFY_COMMIT"


# ---------------------------------------------------------------------------
# Required directories
# ---------------------------------------------------------------------------

mkdir -p \
    "$COMFY_DIR/models/vae" \
    "$COMFY_DIR/models/text_encoders" \
    "$COMFY_DIR/models/diffusion_models" \
    "$COMFY_DIR/models/loras" \
    "$COMFY_DIR/custom_nodes" \
    "$COMFY_DIR/user/default/workflows"


# ---------------------------------------------------------------------------
# Custom nodes
# ---------------------------------------------------------------------------

pin_custom_node() {
    local name="$1"
    local url="$2"
    local commit="$3"

    local dir="$COMFY_DIR/custom_nodes/$name"

    echo
    echo "Custom node: $name"

    if [ ! -d "$dir/.git" ]; then
        rm -rf "$dir"
        git clone "$url" "$dir"
    fi

    git config --global --add safe.directory "$dir" || true

    git -C "$dir" fetch origin "$commit"
    git -C "$dir" checkout --detach "$commit"

    echo "Pinned:"
    git -C "$dir" rev-parse HEAD
}


pin_custom_node \
    "ComfyUI-Manager" \
    "https://github.com/Comfy-Org/ComfyUI-Manager" \
    "$MANAGER_COMMIT"

pin_custom_node \
    "ComfyUI-MiniMax-H3-Turbo" \
    "https://github.com/Larryvrh/ComfyUI-MiniMax-H3-Turbo.git" \
    "$TURBO_COMMIT"

pin_custom_node \
    "comfyui-workflow-to-api-converter-endpoint" \
    "https://github.com/SethRobinson/comfyui-workflow-to-api-converter-endpoint" \
    "$API_CONVERTER_COMMIT"


# ---------------------------------------------------------------------------
# Models
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


# ---------------------------------------------------------------------------
# Known-good workflow
# ---------------------------------------------------------------------------

WORKFLOW_SRC="$VIDEO_DIR/video_minimax_h3_r2v.json"
WORKFLOW_DST="$COMFY_DIR/user/default/workflows/video_minimax_h3_r2v.json"

if [ ! -s "$WORKFLOW_SRC" ]; then
    echo "ERROR: Missing workflow:"
    echo "  $WORKFLOW_SRC"
    exit 1
fi

echo
echo "Installing known-good workflow..."

cp "$WORKFLOW_SRC" "$WORKFLOW_DST"


# ---------------------------------------------------------------------------
# Python dependencies
# ---------------------------------------------------------------------------

echo
echo "Installing ComfyUI requirements..."

if [ -f /venv/main/bin/activate ]; then
    source /venv/main/bin/activate
fi

cd "$COMFY_DIR"

if command -v uv >/dev/null 2>&1; then
    uv pip --no-cache-dir install -r requirements.txt
else
    pip install -r requirements.txt
fi


# ---------------------------------------------------------------------------
# Supervisor config
# ---------------------------------------------------------------------------

if [ ! -s "$VIDEO_DIR/comfyui.conf" ]; then
    echo "ERROR: Missing:"
    echo "  $VIDEO_DIR/comfyui.conf"
    exit 1
fi

cp "$VIDEO_DIR/comfyui.conf" \
   /etc/supervisor/conf.d/comfyui.conf

supervisorctl reread
supervisorctl update


# ---------------------------------------------------------------------------
# Start Comfy
# ---------------------------------------------------------------------------

echo
echo "Starting ComfyUI..."

supervisorctl start comfyui


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

echo
echo "Waiting for ComfyUI on 127.0.0.1:18188..."

READY="false"

for i in $(seq 1 120); do
    if curl -fsS \
        http://127.0.0.1:18188/system_stats \
        >/tmp/is-comfy-stats.json \
        2>/dev/null
    then
        READY="true"
        break
    fi

    sleep 5
done

if [ "$READY" != "true" ]; then
    echo
    echo "ERROR: ComfyUI did not become healthy."

    supervisorctl status comfyui || true

    exit 1
fi


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

echo
echo "=== IS-VIDEO bootstrap complete ==="

echo
echo "ComfyUI:"
git -C "$COMFY_DIR" rev-parse HEAD

echo
echo "Custom nodes:"

for d in \
    "$COMFY_DIR/custom_nodes/ComfyUI-Manager" \
    "$COMFY_DIR/custom_nodes/ComfyUI-MiniMax-H3-Turbo" \
    "$COMFY_DIR/custom_nodes/comfyui-workflow-to-api-converter-endpoint"
do
    echo "$(basename "$d"): $(git -C "$d" rev-parse HEAD)"
done

echo
echo "Service:"
supervisorctl status comfyui

echo
echo "Listener:"
ss -ltnp | grep 18188 || true

echo
echo "Workflow:"
echo "  $WORKFLOW_DST"

echo
echo "Models:"
find "$COMFY_DIR/models" \
    -maxdepth 2 \
    -type f \
    | grep -E 'minimax_h3|qwen3vl' \
    | sort
