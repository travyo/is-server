# IS Server

Reproducible GPU server configuration for the IS project.

This repository supports two Vast.ai server roles:

- **IS-Comfy** — ComfyUI + MiniMax H3 video generation
- **IS-vLLM** — vLLM + Pernicious Prophecy 70B FP8

## IS-Comfy

- Image: `vastai/comfy:v0.30.0-cuda-13.2-py312`
- Disk: 150 GB
- On-start: `entrypoint.sh`
- Internal ComfyUI port: `18188`
- External/template port: `8188`

Automatic provisioning:

`PROVISIONING_GIT_REPOS="https://github.com/travyo/is-server.git|/workspace/is-server|main"`

`PROVISIONING_POST_COMMANDS="/workspace/is-server/bootstrap-video.sh"`

Validation:

    supervisorctl status comfyui
    curl -s http://127.0.0.1:18188/system_stats

Workflow:

    /workspace/ComfyUI/user/default/workflows/video_minimax_h3_r2v.json

See `video/README.md` for details.

## IS-vLLM

- Image: `vastai/vllm:v0.28.0-cuda-13.0`
- Disk: 150 GB
- On-start: `entrypoint.sh`
- Model: `Black-Ink-Guild/Pernicious_Prophecy_70B_FP8`
- Internal API port: `18000`
- Maximum context: `32768`

Automatic provisioning:

`PROVISIONING_GIT_REPOS="https://github.com/travyo/is-server.git|/workspace/is-server|main"`

`PROVISIONING_POST_COMMANDS="/workspace/is-server/bootstrap-llm.sh"`

Validation:

    supervisorctl status vllm
    ss -ltnp | grep 18000
    curl -s http://127.0.0.1:18000/v1/models

First startup can take several minutes while the 70B model downloads, loads, compiles, and performs GPU kernel warmup.

See `llm/README.md` for details.

## Fresh Deployment

A fresh deployment should require only:

1. Rent a compatible Vast.ai GPU.
2. Select `IS-Comfy` or `IS-vLLM`.
3. Launch.
4. Wait for provisioning/model loading.
5. Run the validation commands.

No manual Git clone, GitHub credentials, model installation, or bootstrap commands should be required.
