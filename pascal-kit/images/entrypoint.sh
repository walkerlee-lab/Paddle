#!/bin/bash
# Pascal 离线镜像入口：优先用挂载的配置，其次镜像内烘焙的默认配置，最后在线生成
set -e
CFG=/home/paddleocr/pipeline_config_pascal.yaml
DEFAULT=/home/paddleocr/pipeline_config_default.yaml
if [ ! -f "$CFG" ]; then
    if [ -f "$DEFAULT" ]; then
        cp "$DEFAULT" "$CFG"
        echo "[entrypoint] using baked default pipeline config"
    else
        cd /home/paddleocr
        paddlex --get_pipeline_config PaddleOCR-VL --save_path /home/paddleocr </dev/null \
          || echo . | paddlex --get_pipeline_config PaddleOCR-VL
        mv PaddleOCR-VL.yaml "$CFG"
        echo "[entrypoint] generated default pipeline config at $CFG"
    fi
fi
exec paddlex --serve --pipeline "$CFG" --host 0.0.0.0 --port 8080
