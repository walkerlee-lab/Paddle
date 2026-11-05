#!/bin/bash
# 子模块多源轮换救援：直到全部 init 成功或轮次耗尽
set -e
export DEBIAN_FRONTEND=noninteractive
sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g; s|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
chmod 1777 /tmp
apt-get update -qq && apt-get install -y -qq git
set +e
cd /workspace/paddle || exit 1

# pocketfft：gitlab.mpcdf.mpg.de 协议异常，换 github 官方仓库（同源，含全部历史 commit）
git config submodule.third_party/pocketfft.url https://github.com/mreineck/pocketfft.git

for round in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if git submodule update --init --recursive --jobs 8; then
    echo "SUBMODULES-OK"
    exit 0
  fi
  case $((round % 3)) in
    0)
      git config --global --unset-all url."https://ghfast.top/https://github.com/".insteadOf 2>/dev/null
      git config --global --unset-all url."https://gh-proxy.com/https://github.com/".insteadOf 2>/dev/null
      echo "== round $round: direct github =="
      ;;
    1)
      git config --global url."https://gh-proxy.com/https://github.com/".insteadOf "https://github.com/"
      echo "== round $round: gh-proxy.com =="
      ;;
    2)
      git config --global url."https://ghfast.top/https://github.com/".insteadOf "https://github.com/"
      echo "== round $round: ghfast.top =="
      ;;
  esac
  sleep 5
done
echo "SUBMODULES-STILL-FAILING"
exit 1
