def register_human_localenames
  original_locale = FastGettext.locale
  FastGettext.class.class_eval { attr_accessor :human_available_locales }
  FastGettext.human_available_locales = []
  FastGettext.default_available_locales.each do |locale|
    FastGettext.locale = locale
    # TRANSLATORS: Provide locale name in native language (e.g. English, Deutsch or Português)
    human_locale = _("locale_name")
    human_locale = locale if human_locale == "locale_name"
    FastGettext.human_available_locales << [human_locale, locale]
  end
  FastGettext.human_available_locales.sort! { |a, b| a[0] <=> b[0] }
ensure
  FastGettext.locale = original_locale
end

locale_path = Rails.root.join("config/locales")

FastGettext.add_text_domain('manageiq',
                            :path           => locale_path,
                            :type           => :po,
                            :report_warning => false)
FastGettext.default_available_locales = Dir.entries(locale_path)
  .select { |entry| (File.directory? File.join(locale_path, entry)) && entry != '.' && entry != '..' }
  .sort
FastGettext.default_text_domain = 'manageiq'
register_human_localenames
