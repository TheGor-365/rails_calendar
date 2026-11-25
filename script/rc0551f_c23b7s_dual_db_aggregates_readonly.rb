#!/usr/bin/env ruby
# frozen_string_literal: true

# C2.3b7s: prepared ONLY. No consent exists for this operator; DO NOT execute.
# The only possible future target is fixed local PG16 source and scratch.
# Never invoke from GitHub Actions. Zero file writes/DDL/application boot.
require "etc"
require "json"
require "open3"
require "timeout"
require_relative "../lib/domain_outbox/active_storage_reference_probe"

module C23B7sReadOnlyOperator
  PROBE = DomainOutbox::ActiveStorageReferenceProbe
  PG_BIN = "/usr/lib/postgresql/16/bin/psql"
  SOCKET = "/var/run/postgresql"
  PORT = "5432"
  TOKEN = "YES_ONE_C23B7S_DUAL_DB_AGGREGATE_READ"
  RESTRICTED = %w[
    DATABASE_URL RC_LOCAL_DEV_DATABASE_URL RC_LOCAL_TEST_DATABASE_URL
    PGHOST PGHOSTADDR PGPORT PGUSER PGDATABASE PGSERVICE PGSERVICEFILE
    PGPASSWORD PGPASSFILE PGOPTIONS PGSYSCONFDIR PGTARGETSESSIONATTRS
    PGCONNECT_TIMEOUT PGSSLMODE PGCHANNELBINDING
  ].freeze

  def self.stop!(code)
    warn "STOP C2.3b7s: #{code}"
    exit 2
  end

  def self.read_fixed_json(db, sql)
    settings = {
      "PGOPTIONS" => "-c default_transaction_read_only=on -c statement_timeout=5000 -c lock_timeout=1000",
      "PGCONNECT_TIMEOUT" => "3",
      "PGAPPNAME" => "rc_c23b7s_aggregate_readonly"
    }
    out, _err, status = Timeout.timeout(15) do
      Open3.capture3(settings, PG_BIN, "-X", "-w", "-q", "-A", "-t",
        "-v", "ON_ERROR_STOP=1", "-h", SOCKET, "-p", PORT,
        "-U", PROBE::ROLE, "-d", db, "-c", sql)
    end
    stop!("READ_REJECTED") unless status.success? && out.bytesize < 8192
    JSON.parse(out)
  end

  def self.run!
    stop!("UNEXPECTED_ARGUMENTS") unless ARGV.empty?
    stop!("NEW_EXPLICIT_APPROVAL_REQUIRED") unless
      ENV["RC_APPROVE_C23B7S_AGGREGATES"] == TOKEN
    stop!("TWO_REVIEWED_IDENTITIES_REQUIRED") unless
      ENV["RC_REVIEWED_SOURCE"] == PROBE::SOURCE &&
      ENV["RC_REVIEWED_SCRATCH"] == PROBE::SCRATCH
    stop!("DEVELOPMENT_ONLY") unless
      [nil, "development"].include?(ENV["RAILS_ENV"]) &&
      [nil, "development"].include?(ENV["RACK_ENV"])
    stop!("INHERITED_CONNECTION_CONFIG") if
      RESTRICTED.any? { |k| ENV.key?(k) && !ENV[k].to_s.empty? }
    stop!("WRONG_OS_USER") unless
      Process.uid != 0 && Etc.getpwuid(Process.uid).name == PROBE::ROLE

    root = File.realpath(File.expand_path("..", __dir__))
    stop!("SCRIPT_SYMLINK") if File.symlink?(__FILE__)
    stop!("NO_CONTRACT") unless File.file?(
      File.join(root, "lib/domain_outbox/active_storage_reference_probe.rb")
    )
    expected = ENV["RC_EXPECTED_HEAD_SHA"].to_s
    stop!("BAD_SHA") unless expected.match?(/\A[0-9a-f]{40}\z/)
    git_out, _err, status = Open3.capture3("git", "-C", root, "rev-parse", "HEAD")
    stop!("WRONG_SHA") unless status.success? && git_out.strip == expected
    dirty, _err, status = Open3.capture3(
      "git", "-C", root, "status", "--porcelain"
    )
    stop!("DIRTY_WORKTREE") unless status.success? && dirty.empty?
    stop!("NO_LOCAL_PG16") unless File.executable?(PG_BIN) &&
      File.socket?(File.join(SOCKET, ".s.PGSQL.#{PORT}"))
    version, _err, status = Open3.capture3(PG_BIN, "--version")
    stop!("WRONG_PG_CLIENT") unless status.success? &&
      version.include?("(PostgreSQL) 16.")

    # Fail before application-row aggregate reads if either identity is wrong.
    [PROBE::SOURCE, PROBE::SCRATCH].each do |db|
      PROBE.validate_identity!(read_fixed_json(db, PROBE::IDENTITY_SQL), expected: db)
    end

    a = PROBE.validate_aggregate!(read_fixed_json(PROBE::SOURCE, PROBE::AGGREGATE_SQL))
    b = PROBE.validate_aggregate!(read_fixed_json(PROBE::SCRATCH, PROBE::AGGREGATE_SQL))

    # Session identity rechecked after aggregates. No equality test by row IDs.
    [PROBE::SOURCE, PROBE::SCRATCH].each do |db|
      PROBE.validate_identity!(read_fixed_json(db, PROBE::IDENTITY_SQL), expected: db)
    end

    result = PROBE.assess(source: a, scratch: b)
    puts "C2.3B7S_DB_AGGREGATES=#{result.fetch(:status)}"
    puts "G4_ORPHAN_BLOB_REFS=#{result.fetch(:orphan_blob_references)}"
    puts "G4_MEDIA_KEY_FILE_REFERENCES=NOT_PROVED"
    puts "G6_DB_OTHER_SESSIONS=ZERO_OBSERVED_AT_CHECKS"
    puts "G6_WRITER_QUIESCENCE=NOT_VERIFIED"
    puts "G5_FULL=BLOCKED"
    puts "G7_REPLAY_AND_SCAN=NOT_AUTHORIZED"
    puts "NO_WRITES_BY_THIS_TOOL=TRUE"
    exit 2
  rescue ArgumentError, KeyError, JSON::ParserError, TypeError
    stop!("CONTRACT_OR_IDENTITY_MISMATCH")
  rescue Timeout::Error
    stop!("BOUNDED_READ_TIMEOUT")
  rescue Errno::ENOENT, Errno::EACCES
    stop!("REQUIRED_LOCAL_UTILITY_UNAVAILABLE")
  end
end

C23B7sReadOnlyOperator.run! if $PROGRAM_NAME == __FILE__
