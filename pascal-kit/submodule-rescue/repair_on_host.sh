#!/bin/bash
# 宿主机上检测并修复空壳子模块（不依赖容器 git）
cd /data/pascal-poc/workspace/paddle || exit 1

# 顶层 .gitmodules 定义的子模块路径
TOP_PATHS=$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

echo "=== checking top-level submodules for empty worktrees ==="
EMPTY_LIST=""
for path in $TOP_PATHS; do
  n=$(ls -A "$path" 2>/dev/null | grep -v '^\.git$' | wc -l)
  if [ "$n" = "0" ]; then
    EMPTY_LIST="$EMPTY_LIST $path"
    echo "EMPTY: $path"
  fi
done
[ -z "$EMPTY_LIST" ] && { echo "NO-EMPTY"; exit 0; }

for path in $EMPTY_LIST; do
  sha=$(git ls-tree HEAD "$path" | awk '{print $3}')
  url=$(git config -f .gitmodules submodule."$path".url)
  echo "REPAIR: $path url=$url sha=$sha"
  rm -rf "$path"
  if git clone --quiet "$url" "$path"; then
    if (cd "$path" && git checkout --quiet -f "$sha"); then
      echo "  OK ($path)"
    else
      echo "  CHECKOUT-FAIL ($path)"
    fi
  else
    echo "  CLONE-FAIL ($path)"
  fi
done
echo HOST-REPAIR-DONE
