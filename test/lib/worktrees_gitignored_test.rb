# frozen_string_literal: true

require "test_helper"
require "shellwords"
require "fileutils"

# A per-task desk is cut INSIDE this repo at `.worktrees/<slug>`, and the release
# tooling cuts a `_ship` desk there too. If that path is not ignored, the repo
# reports itself dirty because of an artifact the tooling itself created — and the
# remedy printed alongside that warning is `git add -A && git commit`, which would
# commit every nested worktree into the repo. So the warning is not merely noise:
# following its advice is destructive.
#
# MEASURED 2026-09-03, sweeping every managed repo on origin/main: chain-ops was
# the LAST one without the rule. mcritchie-studio, turf-monster,
# mcritchie-industries, studio-engine, solana-studio, turf-vault and rolio all
# carried it. (The sweep had to read `origin/main`, not the working tree — a
# primary sitting behind reports a rule it already has as missing.)
class WorktreesGitignoredTest < ActiveSupport::TestCase
  test "the worktrees directory is gitignored so a desk cannot dirty the tree" do
    root = Rails.root.to_s
    out = %x(git -C #{Shellwords.escape(root)} check-ignore -v .worktrees/_ship 2>&1)

    assert_predicate $?, :success?,
                     "`.worktrees/` must be gitignored here. `git check-ignore` matched no rule " \
                     "for `.worktrees/_ship`, which means a desk shows up as a dirty primary " \
                     "and the tooling's own rescue advice would commit nested worktrees. " \
                     "Output: #{out.inspect}"
    assert_match(/\.gitignore.*\.worktrees/, out,
                 "the match must come from this repo's .gitignore, naming the .worktrees rule")
  end

  # The property stated as BEHAVIOUR rather than as a file's contents: creating a
  # desk leaves the working tree clean. This is the observation that actually
  # matters, and it would catch a rule that exists but does not match.
  test "a nested worktree directory leaves the working tree clean" do
    root = Rails.root
    probe = root.join(".worktrees", "_gitignore_probe")
    FileUtils.mkdir_p(probe)
    File.write(probe.join("file.txt"), "probe\n")

    dirty = %x(git -C #{Shellwords.escape(root.to_s)} status --porcelain -- .worktrees).strip

    assert_empty dirty,
                 "creating .worktrees/_gitignore_probe left the tree dirty (#{dirty.inspect}); " \
                 "that is exactly the state that makes the release tooling warn about " \
                 "uncommitted work it created itself"
  ensure
    FileUtils.rm_rf(root.join(".worktrees", "_gitignore_probe"))
  end
end
