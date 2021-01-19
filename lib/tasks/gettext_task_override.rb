module GettextI18nRailsJs
  module Task
    # use combined .po
    def files_list
      require "gettext_i18n_rails/tasks"

      ::Pathname.glob(::File.join(locale_path, 'combined', "**", "*.po"))
    end

    # output to ui-classic, not Rails.root; oldjs, not assets/javascripts
    def output_path
      ::ManageIQ::UI::Classic::Engine.root.join('app/javascript/oldjs/locale')
    end

    # use path/lang.json instead of path/lang/app.js
    def destination(lang)
      output_path.mkpath

      path = output_path.join("#{lang}.json")
      path.open("w") do |f|
        f.write yield
      end

      puts "Created #{path}"
    end

    # remove footer asset pipeline references; generate index.js
    def print_footer
      langs =
        files_list
        .map { |f| lang_for(f) }
        .sort
        .map { |lang| "  '#{lang}': require('./#{lang}.json')," }
        .join("\n")

      output_path.join('index.js').write(<<~JS)
        window.locales = {
        #{langs}
        };
      JS

      puts
      puts "All files created, make sure to bin/webpack"
      puts
    end
  end
end
