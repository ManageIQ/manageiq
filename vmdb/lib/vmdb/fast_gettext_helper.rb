module Vmdb
  module FastGettextHelper
    def self.human_locale(locale)
      # TRANSLATORS: Provide locale name in native language (e.g. English, Deutsch or Português)
      human_locale = _("locale_name")
      human_locale = locale if human_locale == "locale_name"
      human_locale
    end

    def self.register_human_localenames
      original_locale = FastGettext.locale
      FastGettext.class.class_eval { attr_accessor :human_available_locales }
      FastGettext.human_available_locales = []
      FastGettext.available_locales.each do |locale|
        FastGettext.locale = locale
        FastGettext.human_available_locales << [human_locale(locale), locale]
      end
      FastGettext.human_available_locales.sort! { |a, b| a[0] <=> b[0] }
    ensure
      FastGettext.locale = original_locale
    end

    def self.fix_i18n_available_locales
      I18n.available_locales += FastGettext.available_locales.grep(/_/).map { |i| i.gsub("_", "-") }
    end

    def self.find_available_locales_via_directories
      Dir.entries(locale_path)
        .select { |entry| (File.directory? File.join(locale_path, entry)) && entry != '.' && entry != '..' }
        .sort
    end

    def self.supported_locales
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

    def self.supported_locales_filename
      @supported_locales_filename ||= File.join(locale_path, "supported.yml")
    end

    def self.supported_locales_specified?
      File.exist?(supported_locales_filename)
    end

    def self.find_available_locales
      available_locales = find_available_locales_via_directories
      available_locales &= supported_locales if supported_locales_specified?
      available_locales
    end

    def self.locale_path
      @locale_path ||= Rails.root.join("config/locales")
    end

    def self.register_locales
      FastGettext.add_text_domain('manageiq',
                                  :path           => locale_path,
                                  :type           => :po,
                                  :report_warning => false)
      FastGettext.available_locales = find_available_locales

      # temporary hack to fix a problem with locales including "_"
      fix_i18n_available_locales
      FastGettext.default_text_domain = 'manageiq'
      register_human_localenames
    end
  end
end
