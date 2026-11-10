require "socket"
require "timeout"
require "time"

module Studio
  # ClamAV INSTREAM. UNIX socket is preferred; a loopback TCP connection is
  # permitted ONLY for local nonproduction Docker development. clamd TCP is
  # unencrypted/unauthenticated; never expose port 3310 publicly.
  class ClamAvScanner
    Verdict = Struct.new(:state, :engine, keyword_init: true)
    class Unavailable < StandardError; end
    MAX_DURATION = 8
    MAX_DATABASE_AGE = 96.hours

    def initialize(socket_factory: nil)
      @socket_factory = socket_factory
    end

    def scan!(bytes)
      Timeout.timeout(MAX_DURATION) do
        verify_database_age! if require_fresh_db?
        with_socket do |socket|
          socket.write("zINSTREAM\0")
          raw = bytes.to_s.b
          offset = 0
          while offset < raw.bytesize
            chunk = raw.byteslice(offset, 64 * 1024)
            socket.write([chunk.bytesize].pack("N"))
            socket.write(chunk)
            offset += chunk.bytesize
          end
          socket.write([0].pack("N"))
          reply = socket.gets("\0").to_s.delete_suffix("\0")
          return Verdict.new(state: "clean", engine: "clamd-instream-v1") if reply.match?(/\A[^\r\n]{1,200}: OK\z/)
          return Verdict.new(state: "infected", engine: "clamd-instream-v1") if reply.match?(/\A[^\r\n]{1,200}: .{1,180} FOUND\z/)
          raise Unavailable, "ClamAV returned an invalid or incomplete verdict"
        end
      end
    rescue Timeout::Error, SystemCallError, IOError, ArgumentError => error
      raise Unavailable, "ClamAV is unavailable (#{error.class})"
    end

    private

    def require_fresh_db?
      ENV["STUDIO_CLAMD_REQUIRE_FRESH_DB"] == "true" ||
        ENV["STUDIO_CLAMD_TCP_HOST"].present?
    end

    def verify_database_age!
      with_socket do |socket|
        socket.write("zVERSION\0")
        reply = socket.gets("\0").to_s.delete_suffix("\0")
        # VERSION includes daemon version, signature revision, and DB date.
        # This verifies timestamp freshness, not authenticity of official CVDs.
        match = reply.match(/\AClamAV [0-9][A-Za-z0-9.+-]*\/[0-9]+\/(.{10,90})\z/)
        raise Unavailable, "ClamAV signature age is unverified" unless match

        updated = Time.parse(match[1])
        age = Time.current - updated
        raise Unavailable, "ClamAV signature database is stale" unless age.between?(-1.hour, MAX_DATABASE_AGE)
      end
    rescue ArgumentError
      raise Unavailable, "ClamAV database timestamp is invalid"
    end

    def with_socket
      path = ENV["STUDIO_CLAMD_UNIX_SOCKET"].to_s
      host = ENV["STUDIO_CLAMD_TCP_HOST"].to_s
      raise Unavailable, "Ambiguous ClamAV transport" if path.present? && host.present?
      raise Unavailable, "ClamAV transport is not configured" if path.empty? && host.empty?

      if host.present?
        # Remote clamd TCP has no transport authentication or encryption.
        # Railway internal TCP requires a separate reviewed implementation.
        unless %w[127.0.0.1 localhost ::1].include?(host) &&
               (Rails.env.test? || Rails.env.development?)
          raise Unavailable, "ClamAV TCP is restricted to local nonproduction loopback"
        end
        port = Integer(ENV.fetch("STUDIO_CLAMD_TCP_PORT", "3310"), exception: false)
        raise Unavailable, "Invalid ClamAV TCP port" unless port&.between?(1, 65_535)
        socket = @socket_factory ? @socket_factory.call : TCPSocket.new(host, port)
      else
        raise Unavailable, "Invalid ClamAV UNIX socket" unless path.start_with?("/") && path.bytesize <= 200
        socket = @socket_factory ? @socket_factory.call : UNIXSocket.open(path)
      end
      begin
        yield socket
      ensure
        socket.close
      end
    end
  end
end
