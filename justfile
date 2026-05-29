dump:
  @scripts/grep_paths.sh -l -o stored/paths.txt && scripts/concat_files.sh stored/paths.txt stored/terminal.txt

test:
  @bash scripts/run_ltos_tests.sh

check:
  @bash scripts/check_layer_boundaries.sh


