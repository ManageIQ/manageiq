describe :locale_name do
  it "all languages have properly set locale_name" do
    Vmdb::FastGettextHelper.find_available_locales.each do |lang|
      FastGettext.locale = lang
      locale_name = _('locale_name')
      expect(locale_name).not_to eq('locale_name')
    end

    FastGettext.locale = 'en' # set the locale for runnin specs back to English
  end

  it "all entries in human_locale_names.yml are valid" do
    YAML.load_file(Rails.root.join('config/human_locale_names.yaml'))['human_locale_names'].each do |locale_name, human_locale_name|
      expect(human_locale_name).not_to be_empty
      expect(human_locale_name).not_to eq(locale_name)
    end
  end
end
