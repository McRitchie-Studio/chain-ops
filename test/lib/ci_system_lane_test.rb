# frozen_string_literal: true

# WHAT LICENSES DROPPING THE SYSTEM TIER FROM .github/workflows/ci.yml.
#
# ci.yml's `test` job runs `bin/rails db:test:prepare test`. That command runs NO system
# tests, and that is only honest while there are none to run. This repo's `test/system`
# holds exactly one file — `.keep` — so the `test:system` tier the command used to carry
# certified nothing, while the job paid for a full google-chrome-stable install and a
# screenshot-upload step to keep it company, on every PR.
#
# THE REMOVAL IS SAFE BECAUSE THE EMPTINESS IS A CHECK, NOT AN ASSUMPTION. Add one system
# test and this file goes RED, naming the file and telling you to restore the tier, the
# browser, and the capture together. That is the entire argument; without this file the
# change is merely cheaper, not safe.
#
# Ported from turf-monster's test/lib/ci_workflow_triggers_test.rb
# (/tasks/drop-turf-empty-system-lane, its PR 365), which removed the identical lane from
# the identical starting state. Only the system-lane guards came across: turf's file also
# pins that repo's release-push triggers, and chain-ops' ci.yml triggers on `main` only,
# so porting those would have asserted a contract this repo does not yet have. Keep the
# copies in sync DELIBERATELY — if turf's grows a vector that applies here, port it on
# purpose.
#
# Run directly:
#   bin/rails test test/lib/ci_system_lane_test.rb
# Also picked up by the plain `bin/rails test` sweep — which is the SAME invocation ci.yml
# runs, so the guard rides inside the very command this change edits. A guard that lives
# outside the lane it protects is a guard nobody runs.
#
# TWO TIERS:
#   [unit]        the detection helpers, over fixture YAML and a fixture tree — proving
#                 each one can actually FIND what it looks for. A guard whose matcher
#                 silently matches nothing passes forever; every helper here is therefore
#                 shown to bite on a positive fixture before it is trusted on a negative.
#   [integration] the REAL committed ci.yml and the REAL test/system tree satisfy the
#                 contract.

require "test_helper"
require "yaml"
require "tmpdir"
require "fileutils"

class CiSystemLaneTest < ActiveSupport::TestCase
  CI_YML = Rails.root.join(".github/workflows/ci.yml")

  # THE EXACT SCRIPT the suite lane must run — not a pattern to match, the whole body.
  # Every guard below reads this constant, so it is the single place a future restoration
  # of the tier has to be declared. Changing it is how you tell this file "the lane came
  # back"; the couplings then flip with it automatically.
  SUITE_SCRIPT = "bin/rails db:test:prepare test"

  # Where Rails writes system-test failure screenshots, and the only thing in this repo
  # that writes there. An upload step pointed here is system-test residue by definition.
  SCREENSHOT_PATH = "tmp/screenshots"

  # Every spelling of "install a browser" this job has plausibly reached for. This one IS
  # a blacklist, and blacklists only catch what their author imagined — so it is BACKED by
  # the coupling assertion's other direction (a restored tier with no browser is also red)
  # and by a unit test proving each alternative actually matches. A new spelling is how
  # this regresses; add it here when you see it.
  BROWSER_STEP = /google-chrome|chrome-stable|setup-chrome|chromedriver|browser-actions/

  # ---- helpers (exercised by the [unit] tier below) ----------------------------------

  # The `test` job's steps. Reached through YAML rather than by grepping text so that a
  # step commented OUT reads as absent (it is) and a step merely reformatted reads as
  # present (it is).
  def steps_of(yaml_text, job = "test")
    Array(YAML.safe_load(yaml_text).dig("jobs", job, "steps")).grep(Hash)
  end

  # Steps whose `run:` body — comments and blank lines stripped — is EXACTLY the pinned
  # script. Exact, not a substring: a substring match accepts `true || bin/rails ...`
  # (never executes), `# bin/rails ...` (commented out), and `bin/rails ... -n /nope/`
  # (runs zero tests), each of which is a green check over an empty suite.
  def suite_lanes(yaml_text)
    steps_of(yaml_text).select do |step|
      body = step["run"].to_s.lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
      body == [ SUITE_SCRIPT ]
    end
  end

  def browser_steps(yaml_text)
    steps_of(yaml_text).select { |s| "#{s["run"]}#{s["uses"]}".match?(BROWSER_STEP) }
  end

  def screenshot_steps(yaml_text)
    steps_of(yaml_text).select { |s| s.to_s.include?(SCREENSHOT_PATH) }
  end

  # The fact the whole change rests on. Takes a root so the [unit] tier can prove the glob
  # FINDS a system test when one exists — otherwise "no files matched" and "the glob is
  # pointed at nothing" are the same passing result, which is exactly how an emptiness
  # guard rots into decoration.
  def system_test_files(root)
    Dir[File.join(root, "test", "system", "**", "*_test.rb")].sort
  end

  # ==== [unit] — the helpers can find what they look for ==============================

  test "unit: the system-test glob finds a system test when one exists" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "test/system/nested"))
      FileUtils.touch(File.join(root, "test/system/.keep"))
      assert_empty system_test_files(root), "a bare .keep must not count as a system test"

      FileUtils.touch(File.join(root, "test/system/nested/dashboard_test.rb"))
      assert_equal [ File.join(root, "test/system/nested/dashboard_test.rb") ],
                   system_test_files(root),
                   "the glob must find a system test at any depth — this is the assertion " \
                   "that makes the integration emptiness check meaningful rather than vacuous"
    end
  end

  test "unit: the suite-lane matcher accepts the real shape and rejects the quiet deformations" do
    lane = ->(script) { "jobs:\n  test:\n    steps:\n      - name: Run tests\n        run: #{script}\n" }

    assert_equal 1, suite_lanes(lane.call(SUITE_SCRIPT)).length, "the pinned script must match"

    {
      "the tier appended back" => "#{SUITE_SCRIPT} test:system",
      "a narrowing filter appended" => "#{SUITE_SCRIPT} -n /nothing_matches_this/",
      "a short-circuit prefix" => "true || #{SUITE_SCRIPT}",
      "commented out" => "'# #{SUITE_SCRIPT}'",
      "gutted to an echo" => "echo skipping"
    }.each do |label, script|
      assert_empty suite_lanes(lane.call(script)),
                   "#{label}: #{script.inspect} must NOT count as the pinned suite lane"
    end
  end

  test "unit: the browser and screenshot matchers bite on the shapes this change removed" do
    removed = <<~YAML
      jobs:
        test:
          steps:
            - name: Install packages
              run: sudo apt-get install -y google-chrome-stable curl
            - name: Keep screenshots from failed system tests
              uses: actions/upload-artifact@v4
              with:
                path: ${{ github.workspace }}/tmp/screenshots
    YAML

    assert_equal [ "Install packages" ], browser_steps(removed).map { |s| s["name"] }
    assert_equal [ "Keep screenshots from failed system tests" ], screenshot_steps(removed).map { |s| s["name"] }
  end

  # ==== [integration] — the live workflow and the live tree ============================

  # ANTI-VACUITY, and it runs first for a reason: every guard below is scoped to the lane
  # that runs SUITE_SCRIPT. If nothing in ci.yml runs it, they all pass having asserted
  # nothing at all.
  test "integration: a lane in the live ci.yml runs exactly the pinned suite script" do
    lanes = suite_lanes(File.read(CI_YML))

    refute_empty lanes,
                 "no step in the live ci.yml has #{SUITE_SCRIPT.inspect} as its whole `run:` " \
                 "body, so every guard in this file is now vacuous. If the suite command " \
                 "legitimately changed, re-point SUITE_SCRIPT deliberately — do not relax the pin."
  end

  test "integration: test/system is empty, which is what licenses omitting the tier" do
    system_dir = Rails.root.join("test/system")
    assert system_dir.directory?,
           "test/system is gone. The emptiness guard now globs a path that cannot match, so " \
           "it would pass vacuously while system tests live somewhere else. Re-point it."

    found = system_test_files(Rails.root.to_s)

    assert_empty found,
                 "#{found.length} system test(s) exist now, and ci.yml's suite command " \
                 "(#{SUITE_SCRIPT.inspect}) does not run them — NOTHING in CI does. Restore the " \
                 "`test:system` task on the suite command, the google-chrome-stable install, and " \
                 "the tmp/screenshots upload in the `test` job, then re-point SUITE_SCRIPT here. " \
                 "Files: #{found.inspect}"
  end

  # The other direction, and the reason these are couplings rather than two more "must be
  # absent" assertions: absence-only guards are satisfied forever by deleting things, and
  # would happily accept a RESTORED system tier running with no browser to drive it and no
  # screenshot to diagnose it. Stated as an equivalence, the pair reads: the job installs a
  # browser IF AND ONLY IF its suite command runs the tier that needs one.
  test "integration: the browser install is coupled to the system tier, both ways" do
    assert_equal SUITE_SCRIPT.include?("test:system"),
                 browser_steps(File.read(CI_YML)).any?,
                 "the `test` job's browser install and its system tier have drifted apart. " \
                 "Either the job installs a browser its suite command (#{SUITE_SCRIPT.inspect}) " \
                 "cannot use — pure cost on every PR — or the tier came back with nothing to " \
                 "drive it, which fails as a mysterious driver error rather than a missing step."
  end

  test "integration: the screenshot upload is coupled to the system tier, both ways" do
    assert_equal SUITE_SCRIPT.include?("test:system"),
                 screenshot_steps(File.read(CI_YML)).any?,
                 "the `test` job's #{SCREENSHOT_PATH} upload and its system tier have drifted " \
                 "apart. Nothing but Rails system tests writes there, so the step is either " \
                 "residue outliving its tier, or a restored tier is running blind."
  end
end
