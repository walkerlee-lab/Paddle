#!/bin/bash
# 检测并修复"空壳子模块"（git 引用对但工作树没 checkout 出文件）
export DEBIAN_FRONTEND=noninteractive
sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g; s|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
chmod 1777 /tmp
apt-get update -qq && apt-get install -y -qq git
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 60

cd /workspace/paddle || exit 1

list_empty() {
    git submodule foreach --recursive 'c=$(ls -A 2>/dev/null | grep -v "^\.git$" | wc -l); [ "$c" = "0" ] && echo "EMPTY:$sm_path"' 2>/dev/null | grep '^EMPTY:' | sed 's/^EMPTY://'
}

echo "=== empty submodule dirs before ==="
BEFORE=$(list_empty)
echo "${BEFORE:-none}"

echo "=== force repair ==="
for m in $BEFORE; do
    echo "repairing $m"
    git submodule update --init --force "$m" || true
done
# 兜底：对仍空的做 deinit + 重clone式 update
for m in $(list_empty); do
    echo "hard repair $m"
    git submodule deinit -f "$m" 2>/dev/null || true
    rm -rf ".git/modules/$m"
    git submodule update --init --force "$m" || true
done

echo "=== empty submodule dirs after ==="
AFTER=$(list_empty)
echo "${AFTER:-none}"
if [ -z "$AFTER" ]; then echo FIX2-DONE; else echo FIX2-INCOMPLETE; fi
