require "socket"
require "timeout"

module Studio
  # clamd INSTREAM over local UNIX socket only. Missing daemon, timeouts and
  # ambiguous replies always fail closed; there is no "trust upload" fallback.
  class ClamAvScanner
    Verdict = Struct.new(:state, :engine, keyword_init: true)
    class Unavailable < StandardError; end

    def scan!(bytes)
      path = ENV["STUDIO_CLAMD_UNIX_SOCKET"].to_s
      raise Unavailable, "ClamAV UNIX socket is not configured" if path.empty?

      Timeout.timeout(8) do
        UNIXSocket.open(path) do |socket|
          socket.write("zINSTREAM\0")
          bytes.to_s.b.bytes.each_slice(64 * 1024) do |chunk|
            socket.write([chunk.length].pack("N"))
            socket.write(chunk.pack("C*"))
          end
          socket.write([0].pack("N"))
          reply = socket.gets("\0").to_s.delete_suffix("\0")
          return Verdict.new(state: "clean", engine: "clamd-instream-v1") if reply.match?(/\A[^\r\n]{1,200}: OK\z/)
          return Verdict.new(state: "infected", engine: "clamd-instream-v1") if reply.match?(/\A[^\r\n]{1,200}: .{1,180} FOUND\z/)
          raise Unavailable, "ClamAV returned an invalid or incomplete verdict"
        end
      end
    rescue Timeout::Error, SystemCallError, IOError => error
      raise Unavailable, "ClamAV is unavailable (#{error.class})"
    end
  end
end
