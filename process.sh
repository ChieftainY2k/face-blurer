#!/bin/bash
# shellcheck disable=SC2086
set -e

screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=0 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=0 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=0 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=0 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=1 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=1 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=1 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
screen docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=1 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py
