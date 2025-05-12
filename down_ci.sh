#!/bin/bash

python3.10 -m venv /3.10
source /3.10/bin/activate
pip3 install nltk huggingface_hub
HF_ENDPOINT=https://hf-mirror.com python3 /ragflow/download_deps.py
