#!/bin/bash
# 编译已完成，补打包依赖后重跑 wheel 打包步骤（增量）
set -e
export DEBIAN_FRONTEND=noninteractive
sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g; s|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
chmod 1777 /tmp
apt-get update -qq
apt-get install -y -qq gcc-11 g++-11 python3.10-dev python3-pip patchelf cmake ccache
pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple -r /workspace/paddle/python/requirements.txt 2>&1 | grep -iE 'error|failed|successfully' | tail -5
pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pyyaml httpx "pybind11_stubgen==2.5.1" 2>&1 | tail -2

cd /workspace/paddle/build
make -j48
ls -la python/dist/
cp python/dist/*.whl /out/
echo "BUILD-DONE"
