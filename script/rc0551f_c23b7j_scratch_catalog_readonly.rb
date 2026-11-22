#!/usr/bin/env ruby
# frozen_string_literal: true

# C2.3b7j: ONE explicitly approved, local PG16 metadata-only scratch query.
# No source DB, table contents, dump, restore, DDL/DML, Rails boot, paid AI,
# replay, merge or network endpoint. NEVER invoke from GitHub Actions.
require "etc"
require "json"
require "open3"
require "timeout"
require_relative "../lib/domain_outbox/six_family_scratch_metadata_probe"

module C23B7jReadOnlyOperator
  PROBE = DomainOutbox::SixFamilyScratchMetadataProbe
  PG_BIN = "/usr/lib/postgresql/16/bin/psql"
  PG_SOCKET = "/var/run/postgresql"
  PG_PORT = "5432"
  APPROVAL = "YES_METADATA_ONLY"
  RESTRICTED_ENV = %w[
    DATABASE_URL RC_LOCAL_DEV_DATABASE_URL PGHOST PGHOSTADDR PGPORT
    PGUSER PGDATABASE PGSERVICE PGSERVICEFILE PGPASSWORD PGOPTIONS
  ].freeze

  def self.stop!(reason)
    warn "STOP C2.3b7j: #{reason}"
    exit 2
  end

  def self.run!
    stop!("unexpected arguments") unless ARGV.empty?
    stop!("explicit metadata-only permission missing") unless
      ENV["RC_APPROVE_C23B7J_METADATA_READ"] == APPROVAL
    stop!("expected isolated scratch identity not confirmed") unless
      ENV["RC_REVIEWED_SCRATCH_NAME"] == PROBE::TARGET
    stop!("development-only context") unless
      [nil, "development"].include?(ENV["RAILS_ENV"]) &&
      [nil, "development"].include?(ENV["RACK_ENV"])
    stop!("inherited application/PostgreSQL context") if
      RESTRICTED_ENV.any? { |key| ENV.key?(key) && !ENV[key].to_s.empty? }

    stop!("wrong operating-system user") unless
      Etc.getpwuid(Process.uid).name == PROBE::ROLE && Process.uid != 0

    root = File.realpath(File.expand_path("..", __dir__))
    stop!("script symlink forbidden") if File.symlink?(__FILE__)
    stop!("missing Ruby/Pg contract") unless
      File.file?(File.join(root, "lib/domain_outbox/six_family_scratch_metadata_probe.rb"))
    expected = ENV["RC_EXPECTED_HEAD_SHA"].to_s
    stop!("40-character pinned checkout SHA required") unless expected.match?(/\A[0-9a-f]{40}\z/)

    git_head, git_err, git_status = Open3.capture3("git", "-C", root, "rev-parse", "HEAD")
    stop!("cannot independently verify checked-out HEAD") unless
      git_status.success? && git_head.strip == expected
    dirty, _err, dirty_status = Open3.capture3(
      "git", "-C", root, "status", "--porcelain", "--untracked-files=no"
    )
    stop!("tracked working tree modified; preserve it") unless
      dirty_status.success? && dirty.empty?

    stop!("pinned local PG16 client/socket absent") unless
      File.executable?(PG_BIN) &&
      File.socket?(File.join(PG_SOCKET, ".s.PGSQL.#{PG_PORT}"))
    version, _err, version_status = Open3.capture3(PG_BIN, "--version")
    stop!("incorrect PG client version") unless
      version_status.success? && version.include?("(PostgreSQL) 16.")

    # All arguments and SQL are application constants; never evaluate a
    # caller-supplied statement, connection URI, table name or file path.
    # -X ignores .psqlrc; -w forbids interactive credential prompts.
    clean_pg_env = {
      "PGOPTIONS" => "-c default_transaction_read_only=on -c statement_timeout=5000 -c lock_timeout=1000",
      "PGCONNECT_TIMEOUT" => "3",
      "PGAPPNAME" => "rc_c23b7j_metadata_readonly"
    }
    stdout, _stderr, status = Timeout.timeout(15) do
      Open3.capture3(
        clean_pg_env, PG_BIN, "-X", "-w", "-q", "-A", "-t",
        "-v", "ON_ERROR_STOP=1", "-h", PG_SOCKET, "-p", PG_PORT,
        "-U", PROBE::ROLE, "-d", PROBE::TARGET, "-c", PROBE::SQL
      )
    end
    stop!("local read-only catalog query unavailable or rejected") unless status.success?

    result = PROBE.assess(JSON.parse(stdout))
    if result.fetch(:status) == "SCHEMA_CATALOG_PASS"
      puts "C2.3B7J_SCRATCH_CATALOG=PASS"
      puts "SCHEMA_MIGRATIONS_AND_17_TABLE_METADATA=PASS"
    else
      puts "C2.3B7J_SCRATCH_CATALOG=BLOCKED"
      result.fetch(:reasons).each { |reason| puts "REVIEW: #{reason}" }
    end
    puts "RESTORE_MEDIA_TENANT_SOURCE_AND_SCAN_AUTHORIZATION=NOT_VERIFIED"
    puts "NO_DATABASE_WRITES_OR_SOURCE_ROWS_READ=TRUE"
    exit(result.fetch(:status) == "SCHEMA_CATALOG_PASS" ? 0 : 2)
  rescue JSON::ParserError, ArgumentError
    stop!("invalid or incomplete metadata-only response")
  rescue Timeout::Error
    stop!("metadata-only SQL timed out")
  rescue Errno::ENOENT, Errno::EACCES
    stop!("required local PG16 or git executable unavailable")
  end
end

C23B7jReadOnlyOperator.run! if $PROGRAM_NAME == __FILE__
