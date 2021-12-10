describe :locale_contents do
  locale_files = Rails.root.join("locale").glob("*.yml")

  context "Copyright year" do
    locale_files.each do |locale_file|
      it locale_file.basename do
        yaml = YAML.load_file(locale_file)
        expect(yaml.fetch_path(yaml.keys.first, "product", "copyright")).to start_with("Copyright (c) #{Time.zone.now.year} ManageIQ.")
      end
    end
  end
end
