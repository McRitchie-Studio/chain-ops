# frozen_string_literal: true

require "test_helper"

# Chain Ops serves its assets through Propshaft (moved off Sprockets 2026-10-25,
# task chain-ops-moves-to-propshaft; recipe from rolio's RUNBOOK, rolio PR 32).
# This guard fails if Sprockets, or a piece of its configuration that Propshaft
# silently ignores, comes back.
#
# Why a guard and not just "the suite is green": every Sprockets-only knob is a
# NO-OP under Propshaft, not an error. A `//= link` manifest, a `*= require_tree`
# directive or `config.assets.precompile += ...` boots fine and does nothing, so a
# stylesheet the directive used to pull in simply stops reaching the browser.
class AssetPipelineTest < ActiveSupport::TestCase
  ROOT = Rails.root

  test "the bundle carries propshaft and not sprockets" do
    gemfile = ROOT.join("Gemfile").read
    lock = ROOT.join("Gemfile.lock").read

    assert_match(/^gem "propshaft"/, gemfile)
    assert_match(/^    propshaft \(/, lock)
    refute_match(/sprockets/, gemfile, "Gemfile names sprockets again")
    refute_match(/^\s+sprockets(-rails)? \(/, lock, "Gemfile.lock resolves sprockets again")
  end

  test "the running app's asset pipeline is propshaft" do
    assert_kind_of Propshaft::Assembly, Rails.application.assets
    refute defined?(::Sprockets), "Sprockets is loaded into the process"
  end

  test "no sprockets manifest or directive is left in app/assets" do
    refute ROOT.join("app/assets/config/manifest.js").exist?,
           "app/assets/config/manifest.js is Sprockets-only; Propshaft serves every file on the load path"

    directives = Dir[ROOT.join("app/assets/**/*.{css,js}")].select do |path|
      File.read(path).match?(%r{^\s*(\*=|//=)\s*(require|link)})
    end
    assert_empty directives.map { |p| Pathname(p).relative_path_from(ROOT).to_s },
                 "Sprockets directives are inert under Propshaft; link the file from the layout instead"
  end

  test "config sets no sprockets-only asset option" do
    sprockets_only = /config\.assets\.(precompile|compile|css_compressor|js_compressor|debug|digest|unknown_asset_fallback)\b/
    offenders = Dir[ROOT.join("config/**/*.rb")].flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, i|
        next if line.lstrip.start_with?("#")

        "#{Pathname(path).relative_path_from(ROOT)}:#{i + 1}" if line.match?(sprockets_only)
      end
    end
    assert_empty offenders, "Propshaft ignores these settings"
  end
end
