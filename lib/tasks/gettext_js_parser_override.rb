module GettextI18nRailsJs
  module Parser
    module Javascript
      #
      # Add TypeScript support to the JS string extraction parser.
      #
      # Backport of https://github.com/webhippie/gettext_i18n_rails_js/pull/125 (released in 3.1.0).
      # Remove this file when gettext_i18n_rails_js is upgraded to 3.1.0 or later.
      #
      # Overrides https://github.com/webhippie/gettext_i18n_rails_js/blob/v1.3.1/lib/gettext_i18n_rails_js/parser/javascript.rb#L36-L43
      def target?(file)
        [
          ".js",
          ".jsx",
          ".ts",
          ".tsx",
          ".vue",
          ".coffee"
        ].include?(::File.extname(file))
      end
    end
  end
end

if Gem::Version.new(GettextI18nRailsJs::Version.to_s) >= Gem::Version.new("3.1.0")
  # TypeScript support was added upstream in 3.1.0, see:
  # https://github.com/webhippie/gettext_i18n_rails_js/pull/125
  warn "This GettextI18nRailsJs TypeScript parser patch is no longer needed as of gettext_i18n_rails_js 3.1.0. Please remove it and its require in locale.rake, see: #{__FILE__}"
end
