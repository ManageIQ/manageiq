class PostgresDsnParser
  def self.parse_dsn(dsn)
    scanner = StringScanner.new(dsn)

    dsn_hash = {}

    until scanner.eos?
      # get the key by matching up to and including the (optionally) white space bordered '='
      key = scanner.scan_until(/\s?=\s?/)
      key = key[0...-scanner.matched_size]

      dsn_hash[key.to_sym] = get_dsn_value(scanner)
    end

    dsn_hash
  end

  def self.get_dsn_value(scanner)
    value = if scanner.peek(1) == "'"
              # if we are a quoted value get the first quote and the
              # string that ends with a quote not preceded by a backslash
              scanner.getch + scanner.scan_until(/(?<!\\)'\s*/).strip
            else
              scanner.scan_until(/\s+|$/).strip
            end

    value = value[1..-2] if value.start_with?("'") && value.end_with?("'")

    # un-escape any single quotes in the remaining value
    value.gsub(/\\'/, "'")
  end
  private_class_method :get_dsn_value
end
