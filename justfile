# justfile — LTOS development tasks
# Usage: just check | just test | just test-suite core | just test-tags unit


root := justfile_directory()

# Layer boundary static check
check:
  @bash {{root}}/scripts/check_layer_boundaries.sh

# Run all spec suites
test:
  @bash {{root}}/scripts/run_ltos_tests.sh

# Run a specific suite (core | modules | runtime | toolchain | integration)
test-suite suite:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--suite','{{suite}}'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# Run tests matching tags (comma-separated)
test-tags tags:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--tags','{{tags}}'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# Fail fast on first failure
test-ff:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--fail-fast'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# Single spec file
test-file file:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" -l {{file}}

# dump current project status
dump:
  @bash {{root}}/scripts/grep_paths.sh -l -o stored/paths.txt \
    && bash {{root}}/scripts/concat_files.sh stored/paths.txt stored/terminal.txt

