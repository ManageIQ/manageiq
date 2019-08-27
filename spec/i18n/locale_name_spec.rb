describe :locale_name do
  it "all languages have properly set locale_name" do
    Vmdb::FastGettextHelper.find_available_locales.each do |lang|
      FastGettext.locale = lang
      locale_name = _('locale_name')
      expect(locale_name).not_to eq('locale_name')
    end

    FastGettext.locale = 'en' # set the locale for runnin specs back to English
  end
end
