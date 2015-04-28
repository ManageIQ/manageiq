def register_human_localenames
  original_locale = FastGettext.locale
  FastGettext.class.class_eval { attr_accessor :human_available_locales }
  FastGettext.human_available_locales = []
  FastGettext.available_locales.each do |locale|
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

def fix_i18n_available_locales
  I18n.available_locales += FastGettext.available_locales.grep(/_/).map { |i| i.gsub("_", "-") }
end

def find_available_locales_via_directories
  Dir.entries(locale_path)
    .select { |entry| (File.directory? File.join(locale_path, entry)) && entry != '.' && entry != '..' }
    .sort
end

def supported_locales
  # Format of YAML file is expected to be as follows
  #  and match the directory names in config/locales
  #
  # ---
  # - en
  # - it
  # - nl
  #
  YAML.load_file(supported_locales_filename)
end

def supported_locales_filename
  File.join(locale_path, "supported.yml")
end

def find_available_locales
  available_locales = find_available_locales_via_directories
  available_locales &= supported_locales if File.exist?(supported_locales_filename)
  available_locales
end

def locale_path
  Rails.root.join("config/locales")
end

old_debug, $DEBUG = $DEBUG, nil
begin
  # The `gettext` gem unreasonably assumes that anyone with $DEBUG
  # enabled must want a flood of racc/yydebug output. As we're actually
  # trying to debug something other than their parser, we need to
  # temporarily force it off while we load stuff.

  FastGettext.add_text_domain('manageiq',
                              :path           => locale_path,
                              :type           => :po,
                              :report_warning => false)
  FastGettext.available_locales = find_available_locales

  # temporary hack to fix a problem with locales including "_"
  fix_i18n_available_locales
  FastGettext.default_text_domain = 'manageiq'
  register_human_localenames
ensure
  $DEBUG = old_debug
end
