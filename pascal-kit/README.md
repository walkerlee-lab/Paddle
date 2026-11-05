# Pascal (sm_60 / sm_61) Port Kit

基于 **Paddle v3.2.2** 的 Pascal 架构移植套件：源码补丁 + 源码编译流水线 + 三级 Docker 镜像链 + 部署编排。

## 实测结论（2026-11-06）

| GPU | 状态 | 说明 |
|---|---|---|
| Tesla P100 (sm_60) | ✅ **全链路通过** | VL 1.6 fp32 单图 1.1s；完整管线 2~4s/页；分项报价表 PDF（2 页密集表格）133s，数字抽查全对 |
| Tesla P40 (sm_61) | ✅ **全链路通过**（2026-11-06 复验） | 好卡（GPU4）实测：VL 1.4s/图、完整管线 2.5s/页。此前『sm_61 elementwise kernel 源码级 bug』结论系测试机 GPU1 硬件故障（坏卡）污染，已推翻——独立 mini kernel 交叉验证：GPU1 崩（sm_60/sm_61 编译产物均复现 CUDA 700），GPU4/5/6 全过 |

## Pascal 上跑 Paddle 的三个独立病根与修复

1. **官方 cu118 wheel 的 Pascal kernel 残缺**（sm_60 缺 CUB SASS 报 CUDA 209；sm_61 部分 kernel 越界）→ 本仓源码重编，`-DCUDA_ARCH_NAME=Pascal` 只编 sm_60/61 原生 SASS。
2. **StreamSafeCUDAAllocator 在 Pascal 上有 bug**（fp32 参数初始化随机 CUDA 700）→ 运行期必须 `FLAGS_allocator_strategy=naive_best_fit`（已烧入 offline 镜像 ENV）。
3. **bf16 权重 GPU 直拷崩溃** → paddlex `model_utils.py` 在 `weight._copy_to` 前先 `astype("float32")`（见 `patches/apply_paddlex_fp32_load.sh`，已烧入镜像构建层）。Pascal 无 bf16/fp16 可靠算术，VL 全程 fp32。

## 三级镜像链（在目标机上构建）

```
第 1 级  images/Dockerfile.cu118     → paddleocr-vl-pascal:cu118
         CUDA 11.8 基底 + paddleocr[doc-parser] 全家桶（官方 cu118 wheel）
第 2 级  images/Dockerfile.rebuild   → paddleocr-vl-pascal:rebuild2
         换自编 Pascal wheel（build_paddle3.sh 产出）+ paddlex fp32 加载补丁
第 3 级  images/Dockerfile.offline   → paddleocr-vl-pascal:offline
         烘焙 4 个模型 + 默认产线配置 + 运行期 ENV，开箱即用
```

## 源码编译（产出 wheel）

```bash
# devel 容器内编译，宿主机只需 docker + 外网（github 时断时续见 submodule-rescue/）
docker run -it -v $PWD:/workspace -v /out:/out \
  docker.m.daocloud.io/nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 bash build_paddle3.sh
# 产出: /out/paddlepaddle_gpu-3.2.2-cp310-cp310-linux_x86_64.whl (~500MB)
```

要点：`-DCUDA_ARCH_NAME=Pascal`（不支持 Custom）；`-DPY_VERSION=3.10`（必须带点）；gcc-11（CUDA 11.8 上限）；打包依赖见 `pack_wheel.sh`（含 `pybind11_stubgen==2.5.1` pin）。增量重编约 40 分钟（48 并发）。

## 部署（offline 镜像）

```bash
GPU_ID=1 docker compose -f pascal-kit/compose.offline.yaml up -d
# API: http://<host>:18081/layout-parsing  (fileType: 0=PDF, 1=图片)
```

镜像内置：PP-DocLayoutV2 / PP-LCNet_x1_0_doc_ori / UVDoc / PaddleOCR-VL-1.6-0.9B（`use_doc_preprocessor: True`），无需外网。

## 已知问题

- **25.13 机器 GPU1 为坏卡**（CUDA 700 非法访问、与内存布局相关的偶发）：部署时避开该卡（nvidia-smi 编号 1），其余 7 张 P40 实测正常。
- 防御性加固：kernel 参数结构体（AlignedPointerWrapper / PointerAndColWrapper / ValueArray / ConstPointerArray / PointerArray）已去除 PADDLE_ALIGN(256)，消除 over-aligned 参数 ABI 的 nvcc 编译告警；与坏卡症状无因果，作为 hardening 保留。
- p1 多表格堆叠的表头行识别为空：文档结构复杂度问题，非 Pascal 特有，需产线参数打磨。
- 官方 `paddleocr genai_server`（vLLM 后端）不适用 Pascal（vLLM/Triton 要求 CC ≥ 7.0）；本方案为 paddlex 进程内单容器推理，无 continuous batching，吞吐低于生产 vLLM 拓扑——定位兜底档。
- wheel 与模型不入库（GitHub 100MB 限制），按上述脚本重新生成。
