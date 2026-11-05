#!/bin/bash
# 修复浅克隆后遗症：主仓库+子模块 unshallow、补 tags、强制对齐 submodule 记录的 commit
export DEBIAN_FRONTEND=noninteractive
sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g; s|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
chmod 1777 /tmp
apt-get update -qq && apt-get install -y -qq git
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 60

cd /workspace/paddle || exit 1
echo "=== unshallow main repo ==="
git fetch --unshallow 2>/dev/null && echo main-unshallow-OK || echo main-repo-full-or-fail

echo "=== submodule unshallow + tags (ignore failures, network flaky) ==="
git submodule foreach --recursive 'git fetch --unshallow 2>/dev/null; git fetch --tags 2>/dev/null; echo done $name' || true

echo "=== force realign submodules ==="
git submodule update --init --recursive --force --jobs 8 || true
git submodule update --init --recursive --force --jobs 8 || true

echo "=== final status (non-clean entries) ==="
git submodule status --recursive | grep -E '^[-+]' | head -20 || true
N=$(git submodule status --recursive | grep -cE '^[-+]')
echo "DIRTY-COUNT=$N"
[ "$N" = "0" ] && echo FIX-DONE || echo FIX-INCOMPLETE
