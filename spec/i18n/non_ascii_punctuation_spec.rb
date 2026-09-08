require "gettext/po_parser"
require "gettext/po"

# English source strings (msgid) must be plain ASCII. Editors and smart-quote
# settings often silently replace ASCII punctuation with Unicode look-alikes.
NON_ASCII_PUNCTUATION = {
  # Ellipsis
  "\u2026" => ["...", "horizontal ellipsis"],

  # Dashes
  "\u2013" => ["-", "en dash"],
  "\u2014" => ["-", "em dash"],
  "\u2015" => ["-", "horizontal bar"],

  # Quotation marks
  "\u2018" => ["'", "left single quotation mark"],
  "\u2019" => ["'", "right single quotation mark"],
  "\u201A" => ["'", "single low-9 quotation mark"],
  "\u201C" => ['"', "left double quotation mark"],
  "\u201D" => ['"', "right double quotation mark"],
  "\u201E" => ['"', "double low-9 quotation mark"],
  "\u00AB" => ['"', "left-pointing double angle quotation mark"],
  "\u00BB" => ['"', "right-pointing double angle quotation mark"],

  # Spaces
  "\u00A0" => [" ", "no-break space"],
  "\u202F" => [" ", "narrow no-break space"],
  "\u2009" => [" ", "thin space"],

  # Multiplication / hyphen look-alikes
  "\u00D7" => ["x", "multiplication sign"],
  "\u2212" => ["-", "minus sign"],
}.freeze

PO_FILES = [
  Rails.root.join("locale/manageiq.pot"),
  Rails.root.join("locale/en/manageiq.po"),
].freeze

RSpec.describe "I18n non-ASCII punctuation" do
  # Parse both source files once and collect all msgid strings containing non-ASCII.
  # Stored as [[po_file, msgid], ...] and shared across all examples.
  before(:all) do
    @non_ascii_msgids = []
    parser = GetText::POParser.new
    parser.report_warning = false
    parser.ignore_fuzzy = true
    PO_FILES.each do |po_file|
      po = GetText::PO.new
      parser.parse_file(po_file.to_s, po)
      po.each do |entry|
        @non_ascii_msgids << [po_file, entry.msgid] if entry.msgid.match?(/[^\x00-\x7F]/)
      end
    end
  end

  def format_errors(errors)
    errors.flat_map do |file, msgids|
      ["File: #{file}"] + msgids.map { |msgid| "  #{msgid.inspect}" }
    end.join("\n")
  end

  # One example per known bad character - reports the suggested ASCII replacement.
  NON_ASCII_PUNCTUATION.each do |char, (ascii_alternative, unicode_name)|
    it "msgid strings must not contain the #{unicode_name} ('#{char}' U+#{"%04X" % char.ord}), use '#{ascii_alternative}' instead" do
      errors = Hash.new { |h, k| h[k] = [] }

      @non_ascii_msgids.each do |po_file, msgid|
        errors[po_file.to_s] << msgid if msgid.include?(char)
      end

      expect(errors).to be_empty,
                        "msgid strings contain the #{unicode_name} ('#{char}' U+#{"%04X" % char.ord}) - use '#{ascii_alternative}' instead:\n\n#{format_errors(errors)}"
    end
  end

  # Catch-all for any non-ASCII character not in the lookup table above.
  it "msgid strings must not contain unknown non-ASCII characters" do
    errors = Hash.new { |h, k| h[k] = [] }

    @non_ascii_msgids.each do |po_file, msgid|
      unknown = msgid.chars.select { |c| c.ord > 127 && !NON_ASCII_PUNCTUATION.key?(c) }
      next if unknown.empty?

      char_names = unknown.uniq.map { |c| "'#{c}' U+%04X" % c.ord }.join(", ")
      errors[po_file.to_s] << "#{msgid}  [#{char_names}]"
    end

    expect(errors).to be_empty,
                      "msgid strings contain non-ASCII characters - add them to NON_ASCII_PUNCTUATION with a suggested replacement, or fix the source string:\n\n#{format_errors(errors)}"
  end
end
