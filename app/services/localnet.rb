# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "pathname"
require "timeout"

class Localnet
  Result = Struct.new(:ok, :message, keyword_init: true) do
    def ok?
      ok
    end
  end

  DEFAULT_RPC_PORT = 8899
  DEFAULT_BIND_ADDRESS = "127.0.0.1"
  DEFAULT_REALM = "local"

  attr_reader :root

  def initialize(root: Rails.root)
    @root = Pathname.new(root.to_s)
  end

  def status
    {
      installed: validator_path.present?,
      validator_path:,
      validator_version:,
      running: running?,
      pid:,
      rpc_health:,
      rpc_url:,
      bind_address:,
      rpc_port:,
      faucet_port:,
      realm:,
      ledger_path: ledger_path.to_s,
      pid_path: pid_path.to_s,
      log_path: log_path.to_s,
      start_command: "bin/localnet start",
      stop_command: "bin/localnet stop",
      reset_command: "bin/localnet reset",
      turf_monster_env:,
      log_tail:
    }
  end

  def start!(reset: false)
    return Result.new(ok: true, message: "Localnet is already running on #{rpc_url}.") if running?
    return Result.new(ok: false, message: "solana-test-validator is not installed or not on PATH.") unless validator_path

    FileUtils.mkdir_p(ledger_path)
    FileUtils.mkdir_p(pid_path.dirname)
    FileUtils.mkdir_p(log_path.dirname)

    log = File.open(log_path, "a")
    log.sync = true
    log.puts
    log.puts "[#{Time.current.iso8601}] starting localnet"

    args = [
      validator_path,
      "--ledger", ledger_path.to_s,
      "--bind-address", bind_address,
      "--rpc-port", rpc_port.to_s,
      "--faucet-port", faucet_port.to_s,
      "--limit-ledger-size"
    ]
    args << "--reset" if reset

    spawned_pid = Process.spawn(*args, chdir: root.to_s, out: log, err: [:child, :out], pgroup: true)
    pid_path.write(spawned_pid.to_s)
    sleep 0.35

    unless process_running?(spawned_pid)
      pid_path.delete if pid_path.exist?
      return Result.new(ok: false, message: "Localnet failed to stay running. Check #{log_path}.")
    end

    Result.new(ok: true, message: "Localnet start requested on #{rpc_url} (PID #{spawned_pid}).")
  ensure
    log&.close
  end

  def stop!
    current_pid = pid
    return Result.new(ok: true, message: "Localnet is already stopped.") unless current_pid && process_running?(current_pid)

    Process.kill("TERM", current_pid)
    30.times do
      break unless process_running?(current_pid)

      sleep 0.1
    end
    Process.kill("KILL", current_pid) if process_running?(current_pid)
    pid_path.delete if pid_path.exist?

    Result.new(ok: true, message: "Localnet stopped.")
  rescue Errno::ESRCH
    pid_path.delete if pid_path.exist?
    Result.new(ok: true, message: "Stale localnet PID cleared.")
  end

  def reset!
    stop!
    FileUtils.rm_rf(ledger_path)
    start!(reset: true)
  end

  def running?
    current_pid = pid
    current_pid.present? && process_running?(current_pid)
  end

  def rpc_url
    ENV.fetch("CHAIN_OPS_LOCALNET_RPC_URL") { "http://#{bind_address}:#{rpc_port}" }
  end

  def realm
    ENV.fetch("SOLANA_REALM", DEFAULT_REALM)
  end

  private

  def bind_address
    ENV.fetch("CHAIN_OPS_LOCALNET_BIND_ADDRESS", DEFAULT_BIND_ADDRESS)
  end

  def rpc_port
    Integer(ENV.fetch("CHAIN_OPS_LOCALNET_RPC_PORT", DEFAULT_RPC_PORT))
  end

  def faucet_port
    Integer(ENV.fetch("CHAIN_OPS_LOCALNET_FAUCET_PORT", 9900))
  end

  def ledger_path
    root.join(ENV.fetch("CHAIN_OPS_LOCALNET_LEDGER", "tmp/solana-ledger"))
  end

  def pid_path
    root.join("tmp", "pids", "solana-test-validator.pid")
  end

  def log_path
    root.join("log", "localnet.log")
  end

  def pid
    return unless pid_path.exist?

    candidate_pid = Integer(pid_path.read.strip)
    process_running?(candidate_pid) ? candidate_pid : nil
  rescue ArgumentError
    nil
  end

  def process_running?(candidate_pid)
    Process.kill(0, candidate_pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end

  def validator_path
    @validator_path ||= begin
      out, _err, status = Open3.capture3("which", "solana-test-validator")
      status.success? ? out.strip : nil
    end
  end

  def validator_version
    return "missing" unless validator_path

    out, err, status = Open3.capture3(validator_path, "--version")
    status.success? ? out.strip : err.strip
  end

  def rpc_health
    uri = URI(rpc_url)
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = JSON.dump(jsonrpc: "2.0", id: 1, method: "getHealth")

    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 0.5, read_timeout: 1) do |http|
      http.request(request)
    end

    body = JSON.parse(response.body)
    body["result"] || body.dig("error", "message") || "unknown"
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EPERM, SocketError, Timeout::Error,
         Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError, URI::InvalidURIError
    "down"
  end

  def turf_monster_env
    {
      "SOLANA_NETWORK" => "localnet",
      "SOLANA_RPC_URL" => rpc_url,
      "SOLANA_REALM" => realm,
      "ANCHOR_PROVIDER_URL" => rpc_url,
      "ANCHOR_WALLET" => "~/.config/solana/id.json"
    }
  end

  def log_tail(lines: 12)
    return [] unless log_path.exist?

    log_path.readlines.last(lines).map(&:chomp)
  rescue Errno::ENOENT
    []
  end
end
