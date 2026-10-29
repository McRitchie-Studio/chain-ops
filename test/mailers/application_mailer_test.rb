require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  # The Rails scaffold's placeholder sender shipped in two apps and Resend
  # refused every send (chain-ops-mail-from-team). Every app sends from
  # team@mcritchie.studio.
  class ProbeMailer < ApplicationMailer
    def hello
      mail(to: "mia@example.com", subject: "Hello") { |format| format.text { render plain: "hi" } }
    end
  end

  test "the default sender is the team address under the app's name" do
    with_env("MAILER_FROM" => nil) do
      assert_equal "Chain Ops <team@mcritchie.studio>", resolved_from
    end
  end

  test "MAILER_FROM overrides the default" do
    with_env("MAILER_FROM" => "Client <hello@client.test>") do
      assert_equal "Client <hello@client.test>", resolved_from
    end
  end

  test "a mail built from ApplicationMailer is sent from team@mcritchie.studio" do
    with_env("MAILER_FROM" => nil) do
      mail = ProbeMailer.hello
      assert_equal [ "team@mcritchie.studio" ], mail.from
      assert_equal "Chain Ops <team@mcritchie.studio>", mail[:from].value
    end
  end

  private

  def resolved_from
    from = ApplicationMailer.default[:from]
    from.respond_to?(:call) ? ApplicationMailer.new.instance_exec(&from) : from
  end

  def with_env(values)
    original = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
