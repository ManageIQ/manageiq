def add_string_chevrons(input)
  "#{"\u00BB".encode("UTF-8")}#{input}#{"\u00AB".encode("UTF-8")}"
end

shared_examples :newlines do |dir|
  it "translations honor newlines" do
    boundary_errors = {}
    overall_errors = {}

    Pathname.glob(File.join(dir, "**", "*.po")).each do |po_file|
      po = FastGettext::PoFile.new(po_file, :report_warning => false)
      locale = po_file.dirname.basename.to_s
      next if locale == 'en' # There's no need to test english .po

      po.data.each do |original, translation|
        next if original.empty? || translation.blank?

        # Check newlines at string ends
        if (translation[-1] == "\n" && original[-1] != "\n") || (translation[-1] != "\n" && original[-1] == "\n")
          boundary_errors.store_path(po_file.to_s, add_string_chevrons(original), add_string_chevrons(translation))
        end

        # Check newlines at string starts
        if (translation[0] == "\n" && original[0] != "\n") || (translation[0] != "\n" && original[0] == "\n")
          boundary_errors.store_path(po_file.to_s, add_string_chevrons(original), add_string_chevrons(translation))
        end

        # Check that overall amount of newlines in original and translation matches
        if original.scan("\n").length != translation.scan("\n").length
          overall_errors.store_path(po_file.to_s, add_string_chevrons(original), add_string_chevrons(translation))
        end
      end
    end

    [['newlines at string boundaries', boundary_errors], ['overall number of newlines', overall_errors]].each do |rule, err|
      next if err.empty?

      puts "The following translation entries do not honor #{rule}:"
      err.each do |file, file_errors|
        puts ">> File: #{file}\n", "----------"
        file_errors.each do |original, translation|
          puts original, translation, "----------"
        end
        puts
      end
    end

    expect(boundary_errors).to be_empty
    # We intentionaly do not expect overall_errors to be empty, since in certain cases it may be desirable
    # for newlines in translated string not to match its original. We'll still be logging the mismatches above.
  end
end
