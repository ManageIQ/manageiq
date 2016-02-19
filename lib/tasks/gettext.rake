namespace :gettext do
  task :store_dictionary_strings do
    output_strings = ["# Strings extracted from en.yml for gettext to find"]
    no_plurals = %w(NFS OS) # strings which we don't want to create automatic plurals for

    dict = YAML.load(File.open(Rails.root.join("config/locales/en.yml")))["en"]["dictionary"]
    dict.keys.each do |tree|
      next unless %w(column model table).include?(tree) # subtrees of interest

      dict[tree].keys.each do |item|
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
          dict[tree][item].keys.each do |subitem|
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
end
