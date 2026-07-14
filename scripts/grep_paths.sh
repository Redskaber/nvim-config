#!/usr/bin/env bash
# path: scripts/grep_paths.sh
# 在指定项目目录下搜索文件，输出路径列表供 concat_files.sh 消耗。
#
# 用法:
#   ./scripts/grep_paths.sh [选项] <pattern> [project_dir]
#   ./scripts/grep_paths.sh -l   [选项]              [project_dir]
#
# 参数:
#   <pattern>       内容匹配的正则表达式（默认模式）
#                   或文件名关键词（配合 -n）
#   [project_dir]   项目根目录，默认为当前目录 (.)
#
# 选项:
#   -i              忽略大小写（内容/文件名匹配均生效）
#   -e <glob>       只搜索匹配 glob 的文件，可多次指定（默认 *.lua）
#   -x <glob>       排除路径含此 glob 的文件，可多次指定
#   -n              按文件名匹配（find -name），而非按内容匹配（grep）
#   -l              列出所有文件（忽略 pattern，仅按 -e/-x 过滤）
#   -o <file>       输出到文件（默认 stdout）
#   -s              排序输出
#   -h              显示帮助
#
# 示例:
#   # 内容含 "CapabilitySet" 的 lua 文件
#   ./scripts/grep_paths.sh "CapabilitySet" lua/
#
#   # 文件名含 "spec" 的文件，输出到 paths.txt
#   ./scripts/grep_paths.sh -n "spec" -o paths.txt spec/
#
#   # 所有 lua 文件（排除 spec/），直接管道给 concat_files.sh
#   ./scripts/grep_paths.sh -l -x "spec/*" -o /tmp/p.txt . \
#     && ./scripts/concat_files.sh /tmp/p.txt output.txt
#
#   # 多种文件类型
#   ./scripts/grep_paths.sh -e "*.lua" -e "*.sh" "require" .

set -euo pipefail

# ── 默认值 ────────────────────────────────────────────────────────────────────
PATTERN=""
PROJECT_DIR="."
CASE_FLAG=""
INCLUDE_GLOBS=()
EXCLUDE_GLOBS=()
NAME_MODE=false
LIST_MODE=false
OUTPUT_FILE=""
SORT_OUTPUT=false

# ── 帮助 ──────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# ── 参数解析 ──────────────────────────────────────────────────────────────────
while getopts ":ie:x:nlso:h" opt; do
  case $opt in
  i) CASE_FLAG="-i" ;;
  e) INCLUDE_GLOBS+=("$OPTARG") ;;
  x) EXCLUDE_GLOBS+=("$OPTARG") ;;
  n) NAME_MODE=true ;;
  l) LIST_MODE=true ;;
  s) SORT_OUTPUT=true ;;
  o) OUTPUT_FILE="$OPTARG" ;;
  h) usage ;;
  :)
    echo "错误: 选项 -$OPTARG 需要参数" >&2
    exit 1
    ;;
  \?)
    echo "错误: 未知选项 -$OPTARG" >&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

# 位置参数
if $LIST_MODE; then
  PROJECT_DIR="${1:-.}"
else
  if [ $# -lt 1 ]; then
    echo "错误: 缺少 <pattern> 参数" >&2
    echo "用法: $0 [选项] <pattern> [project_dir]" >&2
    exit 1
  fi
  PATTERN="$1"
  PROJECT_DIR="${2:-.}"
fi

# 默认 include glob
if [ ${#INCLUDE_GLOBS[@]} -eq 0 ]; then
  INCLUDE_GLOBS=("*.lua")
fi

# ── 构建 find 命令数组 ────────────────────────────────────────────────────────
build_find_cmd() {
  local cmd=(find "$PROJECT_DIR" -type f)

  # include globs: ( -name A -o -name B ... )
  cmd+=("(")
  local first=true
  for glob in "${INCLUDE_GLOBS[@]}"; do
    if $first; then first=false; else cmd+=("-o"); fi
    cmd+=(-name "$glob")
  done
  cmd+=(")")

  # exclude globs
  for glob in "${EXCLUDE_GLOBS[@]}"; do
    cmd+=("!" -path "*/${glob}" "!" -path "./${glob}")
  done

  # file name filter (NAME_MODE)
  if $NAME_MODE && [ -n "$PATTERN" ]; then
    if [ -n "$CASE_FLAG" ]; then
      cmd+=(-iname "*${PATTERN}*")
    else
      cmd+=(-name "*${PATTERN}*")
    fi
  fi

  printf '%s\0' "${cmd[@]}"
}

# ── 执行搜索 ──────────────────────────────────────────────────────────────────
run_search() {
  if $LIST_MODE || $NAME_MODE; then
    # find-based search: read NUL-separated args and exec find
    local find_args=()
    while IFS= read -r -d '' arg; do
      find_args+=("$arg")
    done < <(build_find_cmd)
    "${find_args[@]}" 2>/dev/null || true

  else
    # grep-based content search
    local grep_args=(-rl)
    [ -n "$CASE_FLAG" ] && grep_args+=("$CASE_FLAG")

    for g in "${INCLUDE_GLOBS[@]}"; do
      grep_args+=("--include=$g")
    done
    for g in "${EXCLUDE_GLOBS[@]}"; do
      # exclude both as file glob and as dir
      grep_args+=("--exclude=$g")
      local dir_part="${g%%/*}"
      [ "$dir_part" != "$g" ] && grep_args+=("--exclude-dir=$dir_part")
    done

    grep "${grep_args[@]}" -- "$PATTERN" "$PROJECT_DIR" 2>/dev/null || true
  fi
}

# ── 输出 ──────────────────────────────────────────────────────────────────────
emit() {
  if $SORT_OUTPUT; then
    run_search | sort
  else
    run_search
  fi
}

if [ -n "$OUTPUT_FILE" ]; then
  emit >"$OUTPUT_FILE"
  count=$(wc -l <"$OUTPUT_FILE")
  echo "[grep_paths] $count 条路径 → $OUTPUT_FILE" >&2
else
  emit
fi