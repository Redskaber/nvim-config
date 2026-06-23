# justfile — LTOS development tasks
# Usage: just check | just test | just test-suite core | just test-tags unit

root := justfile_directory()

# Layer boundary static check
check:
  @bash {{root}}/scripts/check_layer_boundaries.sh

# Run all spec suites (full catalogue)
test:
  @bash {{root}}/scripts/run_ltos_tests.sh

# Run a specific suite: core | modules | runtime | toolchain | integration
test-suite suite:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--suite','{{suite}}'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# Run tests matching tags (unit | integration | slow | core | runtime | …)
test-tags tags:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--tags','{{tags}}'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# Stop on first failure
test-ff:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--fail-fast'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# Quiet mode (summary table only, no per-test lines)
test-quiet:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--quiet'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# List all registered test modules
test-list:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    "+lua _G.arg={'--list'}" \
    "+luafile {{root}}/scripts/ltos_tests.lua" \
    +qa

# Run a single spec file directly (headless)
test-file file:
  @nvim --headless \
    -u NONE \
    --cmd "set rtp^={{root}}" \
    -l {{file}}

# Layer check + full test suite (CI entry point)
ci: check test

# Dump current project file tree + concat to stored/
dump:
  @bash {{root}}/scripts/grep_paths.sh -l -o stored/paths.txt \
    && bash {{root}}/scripts/concat_files.sh stored/paths.txt stored/terminal.txt
