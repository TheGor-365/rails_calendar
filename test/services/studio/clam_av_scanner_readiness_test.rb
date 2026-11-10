require "test_helper"

class StudioClamAvScannerReadinessTest < ActiveSupport::TestCase
  FakeSocket = Struct.new(:reply, :writes, :closed, keyword_init: true) do
    def write(bytes)
      self.writes ||= []
      writes << bytes
      bytes.bytesize
    end

    def gets(_delimiter)
      reply + "\0"
    end

    def close
      self.closed = true
    end
  end

  setup do
    @saved = %w[
      STUDIO_CLAMD_UNIX_SOCKET STUDIO_CLAMD_TCP_HOST STUDIO_CLAMD_TCP_PORT
      STUDIO_CLAMD_REQUIRE_FRESH_DB
    ].to_h { |k| [k, ENV[k]] }
    ENV["STUDIO_CLAMD_UNIX_SOCKET"] = "/tmp/rc036-synthetic-test.sock"
    ENV.delete("STUDIO_CLAMD_TCP_HOST")
    ENV.delete("STUDIO_CLAMD_TCP_PORT")
    ENV.delete("STUDIO_CLAMD_REQUIRE_FRESH_DB")
  end

  teardown do
    @saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "UNIX INSTREAM sends exact bytes and accepts explicit OK" do
    socket = FakeSocket.new(reply: "stream: OK")
    verdict = Studio::ClamAvScanner.new(socket_factory: -> { socket }).scan!("# example\n")
    assert_equal "clean", verdict.state
    assert_equal "zINSTREAM\0", socket.writes[0]
    assert_equal [10].pack("N"), socket.writes[1]
    assert_equal "# example\n", socket.writes[2]
    assert_equal [0].pack("N"), socket.writes[3]
    assert socket.closed
  end

  test "explicit FOUND is infected; ambiguous or partial response is denied" do
    verdict = Studio::ClamAvScanner.new(
      socket_factory: -> { FakeSocket.new(reply: "stream: Eicar-Test-Signature FOUND") }
    ).scan!("synthetic")
    assert_equal "infected", verdict.state
    assert_raises(Studio::ClamAvScanner::Unavailable) do
      Studio::ClamAvScanner.new(socket_factory: -> { FakeSocket.new(reply: "stream: UNKNOWN") })
        .scan!("synthetic")
    end
  end

  test "fresh database gate validates separate VERSION request before INSTREAM" do
    ENV["STUDIO_CLAMD_REQUIRE_FRESH_DB"] = "true"
    date = 2.hours.ago.utc.strftime("%a %b %d %H:%M:%S %Y")
    version = FakeSocket.new(reply: "ClamAV 1.4.6/28699/#{date}")
    scan = FakeSocket.new(reply: "stream: OK")
    sockets = [version, scan]
    verdict = Studio::ClamAvScanner.new(socket_factory: -> { sockets.shift }).scan!("synthetic")
    assert_equal "clean", verdict.state
    assert_equal ["zVERSION\0"], version.writes
    assert_equal "zINSTREAM\0", scan.writes.first
    assert version.closed
    assert scan.closed
  end

  test "stale or unrecognizable signature timestamps fail closed" do
    ENV["STUDIO_CLAMD_REQUIRE_FRESH_DB"] = "true"
    stale = 7.days.ago.utc.strftime("%a %b %d %H:%M:%S %Y")
    ["ClamAV 1.4.6/2666/#{stale}", "COMMAND UNAVAILABLE", "unknown"].each do |reply|
      probe = FakeSocket.new(reply: reply)
      assert_raises(Studio::ClamAvScanner::Unavailable) do
        Studio::ClamAvScanner.new(socket_factory: -> { probe }).scan!("synthetic")
      end
      assert_equal ["zVERSION\0"], probe.writes
    end
  end

  test "TCP is local-only and always checks DB version; no remote clamd exposure" do
    ENV.delete("STUDIO_CLAMD_UNIX_SOCKET")
    ENV["STUDIO_CLAMD_TCP_HOST"] = "public.example.test"
    assert_raises(Studio::ClamAvScanner::Unavailable) do
      Studio::ClamAvScanner.new(socket_factory: -> { raise "should not connect" }).scan!("test")
    end
    ENV["STUDIO_CLAMD_TCP_HOST"] = "127.0.0.1"
    ENV["STUDIO_CLAMD_TCP_PORT"] = "3310"
    # Even without explicit freshness flag, TCP requires a valid VERSION reply.
    assert_raises(Studio::ClamAvScanner::Unavailable) do
      Studio::ClamAvScanner.new(socket_factory: -> {
        FakeSocket.new(reply: "COMMAND UNAVAILABLE")
      }).scan!("test")
    end
    ENV["STUDIO_CLAMD_TCP_HOST"] = "127.0.0.1"
    ENV["STUDIO_CLAMD_UNIX_SOCKET"] = "/tmp/other.sock"
    assert_raises(Studio::ClamAvScanner::Unavailable) do
      Studio::ClamAvScanner.new(socket_factory: -> { raise "should not connect" }).scan!("test")
    end
  end
end
