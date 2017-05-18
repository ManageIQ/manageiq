module GettextI18nRailsJs
  module Task
    def files_list
      require "gettext_i18n_rails/tasks"

      ::Pathname.glob(::File.join(locale_path, 'combined', "**", "*.po"))
    end

    def output_path
      ::ManageIQ::UI::Classic::Engine.root.join(GettextI18nRailsJs.config.output_path)
    end
  end
end
