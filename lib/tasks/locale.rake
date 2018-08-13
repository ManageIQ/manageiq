namespace :locale do
  desc "Extract strings from en.yml and store them in a ruby file for gettext:find"
  task :store_dictionary_strings do
    output_strings = [
      "# This is automatically generated file (rake locale:store_dictionary_strings).",
      "# The file contains strings extracted from en.yml for gettext to find."
    ]
    no_plurals = %w(NFS OS) # strings which we don't want to create automatic plurals for

    dict = YAML.safe_load(File.open(Rails.root.join("locale/en.yml")))["en"]["dictionary"]
    dict.each_key do |tree|
      next unless %w(column model table).include?(tree) # subtrees of interest

      dict[tree].each_key do |item|
        if dict[tree][item].kind_of?(String) # leaf node
          output_strings.push("# TRANSLATORS: en.yml key: dictionary.#{tree}.#{item}")
          value = dict[tree][item]
          output_strings.push('_("%s")' % value)

          if %w(model table).include?(tree) && # create automatic plurals for model and table subtrees
             !no_plurals.include?(value)
            m = /(.+)(\s+\(.+\))/.match(value) # strings like: "Infrastructure Provider (Openstack)"
            value_plural = m ? "#{m[1].pluralize}#{m[2]}" : value.pluralize
            if value != value_plural
              output_strings.push("# TRANSLATORS: en.yml key: dictionary.#{tree}.#{item} (plural form)")
              output_strings.push('_("%s")' % value_plural)
            end
          end
        elsif dict[tree][item].kind_of?(Hash) # subtree
          dict[tree][item].each_key do |subitem|
            output_strings.push("# TRANSLATORS: en.yml key: dictionary.#{tree}.#{item}.#{subitem}")
            output_strings.push('_("%s")' % dict[tree][item][subitem])
          end
        end
      end
    end

    File.open(Rails.root.join("config/dictionary_strings.rb"), "w+") do |f|
      f.puts(output_strings)
    end
  end

  desc "Extract strings from various yaml files and store them in a ruby file for gettext:find"
  task :extract_yaml_strings, [:root] => :environment do |_t, args|
    def update_output(string, file, output, root)
      file.gsub!(root + '/', "")
      return if string.blank?
      if output.key?(string)
        output[string].append(file)
      else
        output[string] = [file]
      end
    end

    def parse_object(object, keys, file, output, root)
      if object.kind_of?(Hash)
        object.each_key do |key|
          if keys.include?(key) || keys.include?(key.to_s)
            if object[key].kind_of?(Array)
              object[key].each { |i| update_output(i, file, output, root) }
            else
              update_output(object[key], file, output, root)
            end
          end
          parse_object(object[key], keys, file, output, root)
        end
      elsif object.kind_of?(Array)
        object.each do |item|
          parse_object(item, keys, file, output, root)
        end
      end
    end

    config_file = args[:root].join('config/locale_task_config.yaml')
    next unless config_file.exist?

    yamls = YAML.load_file(config_file)['yaml_strings_to_extract']
    output = {}

    yamls.each_key do |yaml_glob|
      yaml_glob_full = args[:root].join(yaml_glob)
      Dir.glob(yaml_glob_full).each do |file|
        yml = YAML.load_file(file)
        parse_object(yml, yamls[yaml_glob], file, output, args[:root].to_s)
      end
    end

    File.open(args[:root].join("config/yaml_strings.rb"), "w+") do |f|
      f.puts "# This is automatically generated file (rake locale:extract_yaml_strings)."
      f.puts "# The file contains strings extracted from various yaml files for gettext to find."
      output.each_key do |key|
        output[key].sort.uniq.each do |file|
          f.puts "# TRANSLATORS: file: #{file}"
        end
        f.puts '_("%s")' % key
      end
    end
  end

  desc "Extract human locale names from translation catalogs and store them in a yaml file"
  task :extract_locale_names do
    require 'yaml/store'
    require Rails.root.join("lib/vmdb/fast_gettext_helper")

    Vmdb::FastGettextHelper.register_locales

    locale_hash = {}
    FastGettext.available_locales.each do |locale|
      FastGettext.locale = locale
      # TRANSLATORS: Provide locale name in native language (e.g. English, Deutsch or Português)
      human_locale = Vmdb::FastGettextHelper.locale_name
      human_locale = locale if human_locale == "locale_name"
      locale_hash[locale] = human_locale
    end

    store = YAML::Store.new("config/human_locale_names.yaml")
    store.transaction do
      store['human_locale_names'] = locale_hash
    end
  end

  desc "Extract model attribute names and virtual column names"
  task "store_model_attributes" do
    require 'gettext_i18n_rails/model_attributes_finder'
    require_relative 'model_attribute_override.rb'

    attributes_file = 'locale/model_attributes.rb'
    File.unlink(attributes_file) if File.exist?(attributes_file)

    Rake::Task['gettext:store_model_attributes'].invoke

    FileUtils.mv(attributes_file, 'config/model_attributes.rb')
  end

  desc "Run store_model_attributes task in i18n environment"
  task "run_store_model_attributes" do
    system({"RAILS_ENV" => "i18n"}, "bundle exec rake locale:store_model_attributes")
  end

  desc "Update ManageIQ gettext catalogs"
  task "update" do
    Rake::Task['locale:store_dictionary_strings'].invoke
    Rake::Task['locale:run_store_model_attributes'].invoke
    Rake::Task['locale:extract_yaml_strings'].invoke(Rails.root)
    Rake::Task['locale:model_display_names'].invoke
    Rake::Task['gettext:find'].invoke

    Dir["config/dictionary_strings.rb", "config/model_attributes.rb", "config/model_display_names.rb", "config/yaml_strings.rb", "locale/**/*.edit.po", "locale/**/*.po.time_stamp"].each do |file|
      File.unlink(file)
    end
  end

  desc "Extract plugin strings - execute as: rake locale:plugin:find[plugin_name]"
  task "plugin:find", :engine do |_, args|
    unless args[:engine]
      $stderr.puts "You need to specify a plugin name: rake locale:plugin:find[plugin_name]"
      exit 1
    end
    @domain = args[:engine].gsub('::', '_')
    begin
      @engine = "#{args[:engine].camelize}::Engine".constantize
    rescue NameError
      warn "The specified plugin #{args[:engine]} does not exist."
      exit 1
    end
    @engine_root = @engine.root

    # extract plugin's yaml strings
    Rake::Task['locale:extract_yaml_strings'].invoke(@engine_root)

    namespace :gettext do
      def locale_path
        @engine_root.join('locale').to_s
      end

      def files_to_translate
        Dir.glob("#{@engine.root}/{app,db,lib,config,locale}/**/*.{rb,erb,haml,slim,rhtml,js}")
      end

      def text_domain
        @domain
      end
    end

    FastGettext.add_text_domain(@domain,
                                :path           => @engine_root.join('locale').to_s,
                                :type           => :po,
                                :ignore_fuzzy   => true,
                                :report_warning => false)
    Rake::Task['gettext:find'].invoke

    Dir["#{@engine.root}/locale/**/*.edit.po", "#{@engine.root}/locale/**/*.po.time_stamp", "#{@engine.root}/config/yaml_strings.rb"].each do |file|
      File.unlink(file)
    end
  end

  desc "Convert PO files from all plugins to JS files"
  task "po_to_json" => :environment do
    begin
      require_relative 'gettext_task_override.rb'
      require Rails.root.join('lib/manageiq/environment')
      require Rails.root.join("lib/vmdb/gettext/domains")

      po_files = {}
      Vmdb::Gettext::Domains.paths.each do |path|
        files = ::Pathname.glob(::File.join(path, "**", "*.po"))
        files.each do |file|
          locale = file.dirname.basename.to_s
          po_files[locale] ||= []
          po_files[locale].push(file)
        end
      end

      js_plugins = {
        'ui-components' => {
          'en'    => 'https://raw.githubusercontent.com/ManageIQ/ui-components/master/locale/en/ui-components.po',
          'es'    => 'https://raw.githubusercontent.com/ManageIQ/ui-components/master/locale/es/ui-components.po',
          'fr'    => 'https://raw.githubusercontent.com/ManageIQ/ui-components/master/locale/fr/ui-components.po',
          'ja'    => 'https://raw.githubusercontent.com/ManageIQ/ui-components/master/locale/ja/ui-components.po',
          'pt_BR' => 'https://raw.githubusercontent.com/ManageIQ/ui-components/master/locale/pt_BR/ui-components.po',
          'zh_CN' => 'https://raw.githubusercontent.com/ManageIQ/ui-components/master/locale/zh_CN/ui-components.po',
        }
      }

      plugins_dir = File.join(Rails.root, 'locale/plugins')
      Dir.mkdir(plugins_dir, 0700)
      js_plugins.each do |plugin, content|
        plugin_dir = File.join(plugins_dir, plugin)
        Dir.mkdir(plugin_dir)
        content.each do |lang, url|
          lang_dir = File.join(plugin_dir, lang)
          Dir.mkdir(lang_dir)
          lang_file = "#{lang_dir}/#{url.split('/')[-1]}"
          ManageIQ::Environment.system! "curl -f -o #{lang_file} #{url}"
          po_files[lang] ||= []
          po_files[lang].push(Pathname(lang_file))
        end
      end

      combined_dir = File.join(Rails.root, "locale/combined")
      Dir.mkdir(combined_dir, 0700)
      po_files.each_key do |locale|
        dir = File.join(combined_dir, locale)
        po = File.join(dir, 'manageiq.po')
        Dir.mkdir(dir, 0700)
        system "rmsgcat -o #{po} #{po_files[locale].join(' ')}"
      end

      Rake::Task['gettext:po_to_json'].invoke
    ensure
      system "rm -rf #{combined_dir} #{plugins_dir}"
    end
  end

  desc "Create display names for models"
  task "model_display_names" => :environment do
    f = File.open(Rails.root.join("config/model_display_names.rb"), "w+")
    Rails.application.eager_load!
    ApplicationRecord.descendants.sort_by(&:display_name).collect do |model|
      next if model.model_name.singular.titleize != model.display_name || model.display_name.start_with?('ManageIQ')
      f.puts "n_('#{model.display_name}', '#{model.display_name 2}', n)"
    end
    f.close
  end
end
