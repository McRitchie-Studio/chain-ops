# frozen_string_literal: true

# WHAT KEEPS scan_ruby / scan_js / lint HONEST.
#
# All three lanes were RED from 2026-06-27 to 2026-08-21 for reasons no diff caused:
#
#   scan_ruby  bin/brakeman forced --ensure-latest, so brakeman exited 5 ("not the
#              latest version") the moment a newer brakeman was RELEASED upstream --
#              CI failing on an external event, with no code change.
#   scan_js    bin/importmap did not exist (exit 127), and config/importmap.rb did
#              not either, so even with the binstub `audit` raised ENOENT.
#   lint       four Layout/SpaceInsideArrayLiteralBrackets offenses.
#
# The offenses were autocorrected; the other two were structural, and structure is
# what rots back. This file is the check that it does not.
#
# Run directly:
#   bin/rails test test/lib/ci_scan_lanes_test.rb

require "test_helper"
require "yaml"

class CiScanLanesTest < ActiveSupport::TestCase
  ROOT = Rails.root
  CI = YAML.safe_load_file(ROOT.join(".github/workflows/ci.yml"), aliases: true)

  # Match the CODE, not the prose. Both binstubs carry a comment NAMING the flag
  # they dropped -- a naive read of the whole file matches its own explanation.
  def brakeman_code
    ROOT.join("bin/brakeman").read.lines.reject { |l| l.strip.start_with?("#") }.join
  end

  def runs_of(job)
    CI.fetch("jobs").fetch(job).fetch("steps").filter_map { |s| s["run"] }.join("\n")
  end

  # --- scan_ruby ---------------------------------------------------------------

  test "bin/brakeman does not force --ensure-latest" do
    refute_match(/--ensure-latest/, brakeman_code,
                 "--ensure-latest makes brakeman exit 5 on brakeman's RELEASE cadence, " \
                 "not on any finding. Upgrade brakeman via the Gemfile instead.")
  end

  # The other direction, and the one that matters more: the lane must still BITE.
  # --no-exit-on-warn would have made scan_ruby green too -- by making it green
  # forever, for every future warning.
  test "bin/brakeman still exits nonzero on a finding" do
    refute_match(/--no-exit-on-warn/, brakeman_code,
                 "that flag greens scan_ruby permanently. The EOL-Rails finding is " \
                 "silenced by FINGERPRINT in config/brakeman.ignore so every OTHER " \
                 "warning still fails the lane.")
  end

  test "every brakeman ignore carries a note saying why" do
    entries = JSON.parse(ROOT.join("config/brakeman.ignore").read).fetch("ignored_warnings")
    entries.each do |w|
      assert w["note"].to_s.length > 40,
             "brakeman.ignore entry #{w['check_name'].inspect} needs a note explaining " \
             "the debt and when to remove it"
    end
  end

  # --- scan_js -----------------------------------------------------------------

  test "bin/importmap exists and is executable" do
    bin = ROOT.join("bin/importmap")
    assert bin.exist?, "scan_js runs `bin/importmap audit`; without the binstub it exits 127"
    assert bin.executable?, "bin/importmap must be executable"
  end

  test "config/importmap.rb exists for audit to read" do
    assert ROOT.join("config/importmap.rb").exist?,
           "`bin/importmap audit` reads config/importmap.rb and raises ENOENT without it"
  end

  # --- the lanes themselves ----------------------------------------------------
  #
  # Repairing a lane and then deleting it are the same colour on the PR. Pin that
  # each lane still RUNS the command it is named for.
  test "the three scan lanes still run their scanners" do
    assert_match(%r{bin/brakeman}, runs_of("scan_ruby"))
    assert_match(%r{bin/importmap audit}, runs_of("scan_js"))
    assert_match(%r{bin/rubocop}, runs_of("lint"))
  end
end
