# IS-vLLM Deployment

Known-good Vast.ai base image:

vastai/vllm:v0.28.0-cuda-13.0

Model:

Black-Ink-Guild/Pernicious_Prophecy_70B_FP8

Required environment:

VLLM_MODEL=Black-Ink-Guild/Pernicious_Prophecy_70B_FP8

VLLM_ARGS=--host 127.0.0.1 --port 18000 --max-model-len 32768 --gpu-memory-utilization 0.90 --enable-auto-tool-choice --tool-call-parser llama3_json

VLLM_USE_FLASHINFER_SAMPLER=0

AUTO_PARALLEL=true

Vast launch mode:

Interactive shell server, SSH

On-start script:

entrypoint.sh

Internal API:

http://127.0.0.1:18000

The Vast template uses Caddy on port 8000 and proxies to the internal vLLM service on port 18000.

First boot may take several minutes while the 70B model downloads and vLLM builds compile/autotune caches.
