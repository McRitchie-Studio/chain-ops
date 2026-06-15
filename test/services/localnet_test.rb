# frozen_string_literal: true

require "test_helper"

class LocalnetTest < ActiveSupport::TestCase
  test "status exposes the Turf Monster localnet env contract" do
    localnet = Localnet.new
    status = localnet.status

    assert_equal "localnet", status.fetch(:turf_monster_env).fetch("SOLANA_NETWORK")
    assert_equal "local", status.fetch(:turf_monster_env).fetch("SOLANA_REALM")
    assert_equal status.fetch(:rpc_url), status.fetch(:turf_monster_env).fetch("SOLANA_RPC_URL")
    assert_equal status.fetch(:rpc_url), status.fetch(:turf_monster_env).fetch("ANCHOR_PROVIDER_URL")
  end

  test "default status uses app-local process files" do
    localnet = Localnet.new
    status = localnet.status

    assert_includes status.fetch(:ledger_path), "tmp/solana-ledger"
    assert_includes status.fetch(:pid_path), "tmp/pids/solana-test-validator.pid"
    assert_includes status.fetch(:log_path), "log/localnet.log"
  end
end
