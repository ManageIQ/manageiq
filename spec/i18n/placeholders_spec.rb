describe "Placeholders in strings" do
  it "translations preserve placeholders in strings" do
    dirs = [Rails.root.join('locale')]

    Rails::Engine.subclasses.each do |engine|
      dir = engine.root.join('locale')
      dirs << dir if dir.exist?
    end

    errors = {}

    dirs.each do |dir|
      Pathname.glob(File.join(dir, "**", "*.po")).each do |po_file|
        po = FastGettext::PoFile.new(po_file)
        locale = po_file.dirname.basename.to_s
        next if locale == 'en' # There's no need to test english .po
        po.data.each do |original, translation|
          next if translation.nil?
          # Chinese translations do not have plural forms
          original = original.split("\u0000").first if locale == 'zh_CN' && original.present?
          placeholders = original.scan(/%{\w+}/)
          placeholders.sort!
          next if placeholders.empty?
          translated_placeholders = translation.scan(/%{\w+}/)
          translated_placeholders.sort!
          if placeholders.uniq != translated_placeholders.uniq
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
  end
end
