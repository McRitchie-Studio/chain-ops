# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"

# BEHAVIORAL guard for the local log cap.
#
# This repo does NOT depend on studio-engine, so it cannot inherit the
# `studio.logger` initializer that caps every consuming app. The cap lives in
# config/environments/{development,test}.rb instead.
#
# THE ASSERTION IS THE PROPERTY, NOT THE SPELLING. A grep for `log_file_size`
# keeps passing after someone moves the line somewhere Rails reads too late,
# and "too late" is easy to hit: Rails' `:initialize_logger` is a BOOTSTRAP
# initializer, so a cap set from a railtie or engine initializer never applies
# and every command still exits 0. Environment files load before it, which is
# why setting it there works. So each case reads the cap off a logger that was
# actually built.
#
# Background: mcritchie-studio docs/agents/maintenance/kickoff-log-rotation.md
class LogRotationCapTest < ActiveSupport::TestCase
  MB = 1024 * 1024

  # What `config.load_defaults` installs when Rails.env.local? — the value this
  # test exists to keep the app OFF. Named so a failure says which default won.
  RAILS_DEFAULT_CAP = 100 * MB

  # mcritchie-studio's ArtifactSweep::MAX_HEALTHY_CAP: at or above this the
  # archive sweep reports the app LOOSE. Kept as the outer bound so the test
  # still bites if someone raises the literal to something useless.
  HEALTHY_CEILING = 32 * MB

  def device_for(logger)
    resolved = logger.respond_to?(:broadcasts) ? logger.broadcasts.first : logger
    resolved.instance_variable_get(:@logdev)
  end

  test "[unit] the booted test logger carries a bounded rotation cap" do
    device = device_for(Rails.logger)
    assert device, "the booted test logger has no log device at all — nothing is being capped"

    cap = device.instance_variable_get(:@shift_size)
    age = device.instance_variable_get(:@shift_age)

    assert_operator age.to_i, :>, 0,
                    "shift_age is #{age.inspect}: the log never rotates at all, whatever the cap says"
    assert_equal 8 * MB, cap,
                 "expected the 8 MB test cap from config/environments/test.rb"
    refute_equal RAILS_DEFAULT_CAP, cap,
                 "the booted cap is still Rails' own 100 MB default — the config did not take effect"
    assert_operator cap, :<, HEALTHY_CEILING,
                    "a cap at or above #{HEALTHY_CEILING} reads LOOSE in the archive sweep"
  end

  # Development is the environment that actually accumulated the garbage, and
  # it cannot be read from inside a test process: Rails.env and the application
  # singleton are per-process. So boot one, exactly as the archive sweep does.
  # It needs no database — the probe touches no Active Record — which is why
  # this is safe on CI, where only the test database exists.
  test "[integration] a booted development process carries a bounded rotation cap" do
    payload = boot_probe("development")

    assert_operator payload.fetch("shift_age").to_i, :>, 0,
                    "the development log never rotates: shift_age #{payload['shift_age'].inspect}"
    assert_equal 16 * MB, payload.fetch("cap"),
                 "expected the 16 MB development cap from config/environments/development.rb"
    refute_equal RAILS_DEFAULT_CAP, payload.fetch("cap"),
                 "the booted development cap is still Rails' own 100 MB default"
    assert_equal "development.log", File.basename(payload.fetch("path").to_s)
  end

  private

  SNIPPET = <<~RUBY_SNIPPET
    logger = Rails.logger.respond_to?(:broadcasts) ? Rails.logger.broadcasts.first : Rails.logger
    device = logger.instance_variable_get(:@logdev)
    STDOUT.puts("PROBE " + {
      cap: device && device.instance_variable_get(:@shift_size),
      shift_age: device && device.instance_variable_get(:@shift_age),
      path: device && device.filename
    }.to_json)
  RUBY_SNIPPET

  def boot_probe(env)
    out, status = Bundler.with_unbundled_env do
      Open3.capture2e({ "RAILS_ENV" => env }, "bin/rails", "runner", SNIPPET, chdir: Rails.root.to_s)
    end

    # Apps are chatty at boot, so find the marker rather than trusting the last line.
    line = out.lines.reverse.find { |l| l.include?("PROBE ") }
    assert line, "the #{env} boot emitted no probe line (exit #{status.exitstatus}):\n#{out}"

    JSON.parse(line.split("PROBE ", 2).last.strip)
  end
end
