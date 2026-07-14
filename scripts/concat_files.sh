#!/run/current-system/sw/bin/bash
# path: scripts/concat_files.sh
# 用法: ./concat_files.sh <path_list_file> <output_file>
# 示例: ./concat_files.sh paths.txt terminal.txt

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <path_list_file> <output_file>"
  exit 1
fi

PATH_LIST="$1"
OUTPUT_FILE="$2"

>"$OUTPUT_FILE"

while IFS= read -r filepath; do
  if [ -f "$filepath" ]; then
    echo "--- FILE-START: $filepath ---" >>"$OUTPUT_FILE"
    cat "$filepath" >>"$OUTPUT_FILE"
    echo "--- FILE-END ---" >>"$OUTPUT_FILE"
  else
    echo "警告: 文件不存在或不可读: $filepath" >&2
  fi
done <"$PATH_LIST"