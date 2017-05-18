require 'vmdb/gettext/domains'

module Vmdb
  module FastGettextHelper
    def self.register_human_localenames
      human_locale_names = YAML.load_file(Rails.root.join('config/human_locale_names.yaml'))['human_locale_names']

      FastGettext.class.class_eval { attr_accessor :human_available_locales }
      FastGettext.human_available_locales = []
      FastGettext.available_locales.each do |locale|
        FastGettext.human_available_locales << [human_locale_names[locale], locale]
      end
      FastGettext.human_available_locales.sort! { |a, b| a[0] <=> b[0] }
    end

    def self.fix_i18n_available_locales
      I18n.available_locales += FastGettext.available_locales.grep(/_/).map { |i| i.tr("_", "-") }
    end

    def self.find_available_locales_via_directories
      Dir.entries(locale_path)
        .select { |entry| (File.directory? File.join(locale_path, entry)) && entry != '.' && entry != '..' }
        .sort
    end

    def self.supported_locales
      # Format of YAML file is expected to be as follows
      #  and match the directory names in locale/
      #
      # ---
      # - en
      # - it
      # - nl
      #
      YAML.load_file(supported_locales_filename)
    end

    def self.supported_locales_filename
      @supported_locales_filename ||= Rails.root.join("config", "supported_locales.yml")
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
      @locale_path ||= Rails.root.join("locale").to_s
    end

    def self.register_locales
      Vmdb::Gettext::Domains.add_domain(Vmdb::Gettext::Domains::TEXT_DOMAIN, locale_path, :po) # Default ManageIQ domain
      Vmdb::Gettext::Domains.initialize_chain_repo

      FastGettext.default_available_locales = find_available_locales

      # temporary hack to fix a problem with locales including "_"
      fix_i18n_available_locales
      FastGettext.default_text_domain = Vmdb::Gettext::Domains::TEXT_DOMAIN
    end

    def self.locale_name
      _('locale_name')
    end
  end
end
