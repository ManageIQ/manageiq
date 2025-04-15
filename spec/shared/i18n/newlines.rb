def add_string_chevrons(input)
  "#{"\u00BB".encode("UTF-8")}#{input}#{"\u00AB".encode("UTF-8")}"
end

shared_examples :newlines do |dir|
  it "translations honor newlines" do
    string_ends = {}
    string_starts = {}
    overall_errors = {}

    Pathname.glob(File.join(dir, "**", "*.po")).each do |po_file|
      po = FastGettext::PoFile.new(po_file, :report_warning => false)
      locale = po_file.dirname.basename.to_s
      next if locale == 'en' # There's no need to test english .po

      po.data.each do |original, translation|
        next if original.empty? || translation.blank?

        # Check newlines at string ends
        if (translation[-1] == "\n" && original[-1] != "\n") || (translation[-1] != "\n" && original[-1] == "\n")
          string_ends.store_path(po_file.to_s, add_string_chevrons(original), add_string_chevrons(translation))
        end

        # Check newlines at string starts
        if (translation[0] == "\n" && original[0] != "\n") || (translation[0] != "\n" && original[0] == "\n")
          string_starts.store_path(po_file.to_s, add_string_chevrons(original), add_string_chevrons(translation))
        end

        # Check that overall amount of newlines in original and translation matches
        if original.scan("\n").length != translation.scan("\n").length
          overall_errors.store_path(po_file.to_s, add_string_chevrons(original), add_string_chevrons(translation))
        end
      end
    end

    [
      ['no newlines at string ends', string_ends],
      ['no newlines at string start', string_starts],
      ['equal number of overall newlines', overall_errors]
    ].each do |rule, err|
      next if err.empty?

      err_msg = ""
      err.each do |file, file_errors|
        err_msg << "File: #{file}\n"
        file_errors.each do |original, translation|
          err_msg << "  English:\n    #{original.inspect}\n"
          err_msg << "  Translation:\n    #{translation.inspect}\n"
        end
      end
      expect(err).to be_empty, "Rule: #{rule} was violated in:\n #{err_msg}"
    end
  end
end
