#!/bin/bash
# paddlex 3.7.2: bf16 权重 GPU 直拷在 Pascal(sm_60/61) 崩溃（CUDA 700），
# 在 _copy_to 前先 CPU 侧 cast fp32。
# 用法: bash apply_paddlex_fp32_load.sh <paddlex安装根，如 /usr/local/lib/python3.10/dist-packages>
set -e
ROOT="${1:?usage: $0 <site-packages dir>}"
F="$ROOT/paddlex/inference/models/common/transformers/transformers/model_utils.py"
grep -q "astype(\"float32\")" "$F" && { echo "already patched"; exit 0; }
sed -i 's|                    weight = weight._copy_to(|                    if weight.dtype == paddle.bfloat16:\n                        weight = weight.astype("float32")\n                    weight = weight._copy_to(|' "$F"
grep -n "astype(\"float32\")" "$F" | head -2
echo "PATCHED $F"
