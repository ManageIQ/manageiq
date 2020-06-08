describe :locale_name do
  it "all languages have properly set locale_name" do
    Vmdb::FastGettextHelper.find_available_locales.each do |lang|
      FastGettext.with_locale(lang) do
        locale_name = _('locale_name')
        expect(locale_name).not_to eq('locale_name')
      end
    end
  end

  it "all entries in human_locale_names.yml are valid" do
    YAML.load_file(Rails.root.join('config', 'human_locale_names.yaml'))['human_locale_names'].each do |locale_name, human_locale_name|
      expect(human_locale_name).not_to be_empty
      expect(human_locale_name).not_to eq(locale_name)
    end
  end

  it "all languages have properly set human_locale_name" do
    human_locale_names = YAML.load_file(Rails.root.join('config', 'human_locale_names.yaml'))['human_locale_names']
    locales = Vmdb::FastGettextHelper.find_available_locales

    expect(human_locale_names.keys.sort).to eq(locales.sort)

    locales.each do |locale|
      expect(human_locale_names[locale]).not_to be_empty
      expect(human_locale_names[locale]).not_to eq(locale)
    end
  end
end
