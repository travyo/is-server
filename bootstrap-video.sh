#!/usr/bin/env bash
set -euo pipefail

echo "=== IS-VIDEO bootstrap starting ==="

# Disable Vast auto-tmux
touch /root/.no_auto_tmux

COMFY_DIR="/workspace/ComfyUI"
VIDEO_DIR="/workspace/is-server/video"

mkdir -p \
  "$COMFY_DIR/models/vae" \
  "$COMFY_DIR/models/text_encoders" \
  "$COMFY_DIR/models/diffusion_models" \
  "$COMFY_DIR/models/loras" \
  "$COMFY_DIR/user/default/workflows"

# Copy known-good workflow
cp "$VIDEO_DIR/video_minimax_h3_r2v.json" \
   "$COMFY_DIR/user/default/workflows/video_minimax_h3_r2v.json"

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

# Install known-good Supervisor config
cp "$VIDEO_DIR/comfyui.conf" /etc/supervisor/conf.d/comfyui.conf

supervisorctl reread
supervisorctl update
supervisorctl restart comfyui

echo
echo "=== IS-VIDEO bootstrap complete ==="
echo
echo "Check:"
echo "  supervisorctl status comfyui"
echo
echo "Internal UI:"
echo "  http://127.0.0.1:18188"
echo
echo "Workflow:"
echo "  video_minimax_h3_r2v.json"
