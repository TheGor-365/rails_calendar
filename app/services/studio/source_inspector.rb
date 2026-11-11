require "digest"
require "json"

module Studio
  # Offline, non-persisting preview of a *synthetic/non-sensitive* source.
  # It does not handle private production files, HTML, archives, OCR or AI.
  # Never execute content: uploaded strings are untrusted evidence.
  class SourceInspector
    MAX_BYTES = 256 * 1024
    MAX_SECTIONS = 60
    MAX_ITEMS = 80
    EXTENSIONS = { ".md" => "markdown", ".markdown" => "markdown",
                   ".txt" => "text", ".json" => "json" }.freeze

    def call(filename:, bytes:)
      name = File.basename(filename.to_s)
      extension = File.extname(name).downcase
      format = EXTENSIONS[extension]
      raise ArgumentError, "Unsupported source format" unless format
      raise ArgumentError, "Filename too long" unless name.bytesize.between?(1, 180)

      raw = bytes.to_s.b
      raise ArgumentError, "Empty source" if raw.empty?
      raise ArgumentError, "Source is too large" if raw.bytesize > MAX_BYTES

      text = raw.dup.force_encoding(Encoding::UTF_8)
      raise ArgumentError, "Invalid UTF-8 source" unless text.valid_encoding?
      raise ArgumentError, "Binary content is not allowed" if text.include?("\u0000")
      text = text.delete_prefix("\uFEFF").gsub("\r\n", "\n")
      digest = Digest::SHA256.hexdigest(raw)
      if format == "json"
        decoded = JSON.parse(text, max_nesting: 8, allow_nan: false)
        raise ArgumentError, "JSON source must be an object or array" unless decoded.is_a?(Hash) || decoded.is_a?(Array)

        return {
          "format" => format, "sha256" => digest, "bytes" => raw.bytesize,
          "line_count" => text.lines.count,
          "outline" => [],
          "checklist" => [],
          "json_root" => decoded.is_a?(Hash) ? "object" : "array",
          "json_top_level_keys" => decoded.is_a?(Hash) ? decoded.keys.first(MAX_SECTIONS) : [],
          "classification" => "UNTRUSTED_OWNER_PREVIEW_NOT_PERSISTED",
          "stored" => false, "provider_ready" => false
        }
      end

      sections = []
      items = []
      text.each_line.with_index(1) do |line, index|
        if format == "markdown" && sections.size < MAX_SECTIONS
          heading = line.match(/\A {0,3}([#]{1,6})[ \t]+(.+?)\s*\z/)
          sections << { "level" => heading[1].length, "line" => index,
                        "title" => heading[2].strip.slice(0, 160) } if heading
        end

        next unless format == "markdown" && items.size < MAX_ITEMS

        task = line.match(/\A\s*[-*]\s+\[([ xX])\]\s+(.+?)\s*\z/)
        items << { "line" => index, "done" => task[1].downcase == "x",
                   "text" => task[2].strip.slice(0, 200) } if task
      end

      {
        "format" => format, "sha256" => digest, "bytes" => raw.bytesize,
        "line_count" => text.lines.count,
        "outline" => sections, "checklist" => items,
        "classification" => "UNTRUSTED_OWNER_PREVIEW_NOT_PERSISTED",
        "stored" => false, "provider_ready" => false
      }
    rescue JSON::ParserError, JSON::NestingError
      raise ArgumentError, "Invalid or deeply nested JSON source"
    end
  end
end
