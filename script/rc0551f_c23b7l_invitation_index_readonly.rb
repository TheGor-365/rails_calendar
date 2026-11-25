#!/usr/bin/env ruby
# frozen_string_literal: true

# ONE NEW separately authorized index-only PG16 scratch metadata observation.
# Never run from CI; no source rows, DDL/DML, backup, replay, Railway or Rails boot.
require "etc"
require "json"
require "open3"
require "timeout"
require_relative "../lib/domain_outbox/invitation_index_metadata_triage"
require_relative "../lib/domain_outbox/invitation_index_metadata_discriminator"

module C23B7lInvitationIndexOperator
  PROBE = DomainOutbox::InvitationIndexMetadataTriage
  DISCRIMINATOR = DomainOutbox::InvitationIndexMetadataDiscriminator
  PG_BIN = "/usr/lib/postgresql/16/bin/psql"
  PG_SOCKET = "/var/run/postgresql"
  PG_PORT = "5432"
  APPROVAL = "YES_ONE_C23B7L_INDEX_CATALOG_READ"
  RESTRICTED_ENV = %w[
    DATABASE_URL RC_LOCAL_DEV_DATABASE_URL RC_LOCAL_TEST_DATABASE_URL
    PGHOST PGHOSTADDR PGPORT PGUSER PGDATABASE PGSERVICE PGSERVICEFILE
    PGPASSWORD PGPASSFILE PGOPTIONS PGSYSCONFDIR PGTARGETSESSIONATTRS
    PGCONNECT_TIMEOUT PGSSLMODE PGCHANNELBINDING
  ].freeze

  def self.stop!(reason)
    warn "STOP C2.3b7l: #{reason}"
    exit 2
  end

  def self.run!
    stop!("unexpected arguments") unless ARGV.empty?
    stop!("new, separate one-query authorization missing") unless
      ENV["RC_APPROVE_C23B7L_INDEX_READ"] == APPROVAL
    stop!("wrong reviewed scratch identity") unless
      ENV["RC_REVIEWED_SCRATCH_NAME"] == PROBE::TARGET
    stop!("development-only context") unless
      [nil, "development"].include?(ENV["RAILS_ENV"]) &&
      [nil, "development"].include?(ENV["RACK_ENV"])
    stop!("inherited application/PostgreSQL context") if
      RESTRICTED_ENV.any? { |key| ENV.key?(key) && !ENV[key].to_s.empty? }
    stop!("wrong OS user") unless
      Process.uid != 0 && Etc.getpwuid(Process.uid).name == PROBE::ROLE

    root = File.realpath(File.expand_path("..", __dir__))
    stop!("operator symlink forbidden") if File.symlink?(__FILE__)
    stop!("missing probe") unless
      File.file?(File.join(root, "lib/domain_outbox/invitation_index_metadata_triage.rb"))
    expected = ENV["RC_EXPECTED_HEAD_SHA"].to_s
    stop!("reviewed 40-character SHA required") unless expected.match?(/\A[0-9a-f]{40}\z/)

    head, _stderr, git_status = Open3.capture3("git", "-C", root, "rev-parse", "HEAD")
    stop!("checked-out HEAD differs from reviewed SHA") unless
      git_status.success? && head.strip == expected
    dirty, _stderr, git_status = Open3.capture3(
      "git", "-C", root, "status", "--porcelain", "--untracked-files=no"
    )
    stop!("tracked worktree changes: preserve existing files") unless
      git_status.success? && dirty.empty?

    stop!("pinned local PG16 client/socket unavailable") unless
      File.executable?(PG_BIN) &&
      File.socket?(File.join(PG_SOCKET, ".s.PGSQL.#{PG_PORT}"))
    version, _stderr, pg_status = Open3.capture3(PG_BIN, "--version")
    stop!("wrong PostgreSQL client major") unless
      pg_status.success? && version.include?("(PostgreSQL) 16.")

    pg_env = {
      "PGOPTIONS" => "-c default_transaction_read_only=on -c statement_timeout=5000 -c lock_timeout=1000",
      "PGCONNECT_TIMEOUT" => "3",
      "PGAPPNAME" => "rc_c23b7l_index_catalog_readonly"
    }
    stdout, _stderr, status = Timeout.timeout(15) do
      Open3.capture3(
        pg_env, PG_BIN, "-X", "-w", "-q", "-A", "-t",
        "-v", "ON_ERROR_STOP=1", "-h", PG_SOCKET, "-p", PG_PORT,
        "-U", PROBE::ROLE, "-d", PROBE::TARGET, "-c", PROBE::SQL
      )
    end
    stop!("local catalog query unavailable or rejected") unless status.success?

    result = DISCRIMINATOR.evaluate(JSON.parse(stdout))
    stop!("stale or unclassified metadata") if result.nil?
    stop!("unexpected variant") unless DISCRIMINATOR::VARIANTS.include?(result.fetch(:variant))
    stop!("unexpected identifier") unless result.fetch(:name).match?(/\A[a-zA-Z0-9_]{1,90}\z/)
    stop!("unexpected delta") unless
      result.fetch(:delta).split(",").all? do |field|
        DISCRIMINATOR::DIFFERENCES.include?(field)
      end
    puts "C2.3B7L_INDEX_VARIANT=#{result.fetch(:variant)}"
    puts "C2.3B7L_INDEX_NAME=#{result.fetch(:name)}"
    puts "C2.3B7L_DIFFERENCES=#{result.fetch(:delta)}"
    puts "G5=BLOCKED"
    puts "DATABASE_WRITES_AND_APPLICATION_ROW_READS=NOT_PERFORMED_BY_THIS_TOOL"
    puts "BACKUP_MEDIA_TENANCY_AND_REMEDIATION=NOT_AUTHORIZED"
    exit 2 # Never clear G5 based on index metadata alone.
  rescue JSON::ParserError, ArgumentError, KeyError
    stop!("incomplete or invalid metadata response")
  rescue Timeout::Error
    stop!("catalog read timed out")
  rescue Errno::ENOENT, Errno::EACCES
    stop!("required local executable unavailable")
  end
end

C23B7lInvitationIndexOperator.run! if $PROGRAM_NAME == __FILE__
