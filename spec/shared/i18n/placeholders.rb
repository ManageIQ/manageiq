shared_examples :placeholders do |dir|
  it "translations preserve placeholders in strings" do
    errors = {}
    false_negatives = {}
    incorrect_plurals = []

    Pathname.glob(File.join(dir, "**", "*.po")).each do |po_file|
      po = FastGettext::PoFile.new(po_file, :report_warning => false)
      locale = po_file.dirname.basename.to_s
      false_negatives[po_file.to_s] = []
      next if locale == 'en' # There's no need to test english .po

      #########################################################
      # Looks like the following in the .po file
      # de:    "Plural-Forms: nplurals=2; plural=n != 1;\n"
      # en:    "Plural-Forms: nplurals=2; plural=n != 1;\n"
      # es:    "Plural-Forms: nplurals=2; plural=n != 1;\n"
      # fr:    "Plural-Forms: nplurals=2; plural=n>1;\n"
      # it:    "Plural-Forms: nplurals=2; plural=n != 1;\n"
      # ja:    "Plural-Forms: nplurals=1; plural=0;\n"
      # ko:    "Plural-Forms: nplurals=1; plural=0;\n"
      # pt_BR: "Plural-Forms: nplurals=2; plural=n>1;\n"
      # zh_CN: "Plural-Forms: nplurals=1; plural=0;\n"
      # zh_TW: "Plural-Forms: nplurals=1; plural=0;\n"
      #
      # For languages that do not support pluralizations,
      #  nplurals = 1
      #
      # So, calling the pluralisation_rule on a number > 1
      #  can tell us if pluralisation is supported or not
      #########################################################
      plural_unsupported = (po.pluralisation_rule.call(3) == 0)

      po.data.each do |original, translation|
        next if translation.nil? || !original.include?("%{") # Skip if string is not translated or original does not contain %{}

        if plural_unsupported && original.include?("\u0000") # For languages that do not support pluralisation
          if translation.include?("\u0000") # there should be only one translated form
            incorrect_plurals << translation
            next
          end
          singular, plural = original.split("\u0000").map { |str| str.scan(/%{\w+}/).sort.uniq }
          translated_placeholders = translation.scan(/%{\w+}/).sort!.uniq
          if singular != translated_placeholders && plural != translated_placeholders
            errors.store_path(po_file.to_s, original, translation)
          end
          false_negatives[po_file.to_s].append(original.split("\u0000").first)
        else
          origin = original.scan(/%{\w+}/).sort.uniq
          transl = translation.scan(/%{\w+}/).sort.uniq
          if origin != transl && !false_negatives[po_file.to_s].include?(original)
            errors.store_path(po_file.to_s, original, translation)
          end
        end
      end
    end

    if errors.present?
      errors.each do |file, file_errors|
        puts ">> #{file}\n"
        file_errors.each do |original, translation|
          puts original, translation, ""
        end
        puts
      end
    end
    expect(errors).to be_empty
    expect(incorrect_plurals).to be_empty
  end

  it "gettext strings do not contain interpolations" do
    errors = []
    Pathname.glob(File.join(dir, "**", "*.pot")).each do |pot_file|
      File.open(pot_file).each do |line|
        next unless line =~ /^.+"(.*\#\{.+\})/

        errors.push($1)
      end
    end

    if errors.present?
      puts "Interpolations found in the catalog:\n"
      puts errors
    end
    expect(errors).to be_empty
  end
end
