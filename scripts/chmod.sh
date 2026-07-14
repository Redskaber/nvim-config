#!/run/current-system/sw/bin/bash
# path: scripts/concat_files.sh
# 用法: ./concat_files.sh <path_list_file> <output_file>
# 示例: ./concat_files.sh paths.txt terminal.txt

PATH_LIST="$1"

while IFS= read -r filepath; do
  if [ -f "$filepath" ]; then
    chmod -x "$filepath"
  else
    echo "警告: 文件不存在或不可读: $filepath" >&2
  fi
done <"$PATH_LIST"