# IS-Comfy Deployment

Known-good Vast.ai base image:

vastai/comfy:v0.30.0-cuda-13.2-py312

## Runtime

ComfyUI: 0.30.0
Python: 3.12
CUDA image: 13.2

## Vast Template

Launch mode:

Interactive shell server, SSH

On-start script:

entrypoint.sh

Disk:

150 GB

Direct SSH:

Enabled

## ComfyUI API

Internal ComfyUI service:

http://127.0.0.1:18188

Template/external ComfyUI port:

8188

COMFYUI_API_BASE=http://localhost:18188

## Ports

The known-good Vast template retains these TCP ports:

1111
8080
8188
8288
8384
10100
10200
72299

## Provisioning

Clone this repository to:

/workspace/is-server

Then run:

cd /workspace/is-server
./bootstrap-video.sh

bootstrap-video.sh installs the required MiniMax H3 models and Turbo LoRA if missing, installs the known-good workflow, and configures the Vast-managed ComfyUI service.

Workflow destination:

/workspace/ComfyUI/user/default/workflows/video_minimax_h3_r2v.json

## Model Stack

Diffusion model:

minimax_h3_ref2va_pruned_int8_convrot.safetensors

Text encoder:

qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors

Video VAE:

minimax_h3_video_vae_fp16.safetensors

Audio VAE:

minimax_h3_audio_vae_fp32.safetensors

Turbo LoRA:

minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors

## Notes

Keep entrypoint.sh as the Vast On-start Script. It initializes the services expected by the Vast ComfyUI image.

The Vast template remains the host-specific deployment layer. The portable video configuration, workflow, model manifest, and provisioning logic live in this repository.
