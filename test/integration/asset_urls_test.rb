# frozen_string_literal: true

require "test_helper"

# Every asset a page links must resolve through Propshaft: a fingerprinted URL
# (name-<digest>.ext) that answers 200 with bytes. This covers the stylesheets
# and any <script src>, <link href> or <img src> under /assets, plus the
# importmap's pins. Ported from rolio's guard (rolio PR 32).
#
# chain-ops pins no JavaScript today (config/importmap.rb is empty and no view
# emits importmap tags), so the pin check holds the declared set to what
# importmap-rails loaded and each pin to a fingerprinted file. It starts biting
# the moment the first `pin` lands: importmap-rails RESCUES a pin whose file is
# missing and silently drops it from the rendered map, so a missing file would
# otherwise never fail a request.
class AssetUrlsTest < ActionDispatch::IntegrationTest
  DIGESTED = %r{\A/assets/.+-[0-9a-f]{8,}\.[a-z0-9]+\z}

  # Every page that renders the application layout.
  PAGES = [ "/" ].freeze

  def asset_urls_on(path)
    get path
    follow_redirect! while response.redirect?
    assert_response :success, "#{path} did not render"

    html = response.body
    urls = html.scan(%r{(?:href|src)="(/assets/[^"]+)"}).flatten
    importmap = html[%r{<script type="importmap"[^>]*>(.*?)</script>}m, 1]
    urls += JSON.parse(importmap).fetch("imports").values if importmap
    urls.uniq
  end

  test "every asset on the main pages is fingerprinted and answers 200" do
    checked = PAGES.flat_map { |page| asset_urls_on(page).map { |url| [ page, url ] } }.uniq(&:last)
    assert checked.any? { |_, url| url.end_with?(".css") }, "no stylesheet was linked"

    checked.each do |page, url|
      assert_match DIGESTED, url, "#{page} links an undigested asset"
      get url
      assert_response :success, "#{url} (linked from #{page}) did not resolve"
      refute_empty response.body, "#{url} served no bytes"
    end
  end

  test "every importmap pin resolves to a fingerprinted asset" do
    declared = Rails.root.join("config/importmap.rb").readlines.grep(/^\s*pin(_all_from)?\b/)
    pins = Rails.application.importmap.packages
    assert_equal declared.grep(/^\s*pin\b/).size, pins.size,
                 "config/importmap.rb declares a different pin set than importmap-rails loaded" if declared.grep(/pin_all_from/).empty?

    helpers = ActionController::Base.helpers
    pins.each do |name, package|
      url = helpers.asset_path(package.path)
      assert_match DIGESTED, url, "pin #{name} resolves undigested"
    rescue Propshaft::MissingAssetError => e
      flunk "pin #{name} points at a file Propshaft cannot find: #{e.message}"
    end
  end
end
