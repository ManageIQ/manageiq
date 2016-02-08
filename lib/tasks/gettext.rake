# work around to get past the 'ui_constants' inclusion errors
def ui_lookup(_)
end

require_relative '../../app/helpers/ui_constants'

namespace :gettext do
  task :store_toolbar_strings do
    toolbar_strings_file = Rails.root.join("config/toolbar_strings.rb")
    gettext_strings = []
    tb_keys = [:text, :title, :confirm] # toolbar keys of interest

    Dir.glob("#{Rails.root.join(TOOLBARS_FOLDER)}" + "/*.yaml").sort.each do |tb_file|
      tb_hash = YAML.load(File.open(tb_file))
      next unless tb_hash # skip empty yaml files

      tb_hash[:button_groups].each do |bg|
        bg[:items].each do |bgi|
          tb_keys.each do |k|
            gettext_strings.push("_(\"#{bgi[k]}\")") if bgi[k]
          end
          next unless bgi[:items]
          bgi[:items].each do |bt|
            tb_keys.each do |k|
              gettext_strings.push("_(\"#{bt[k]}\")") if bt[k]
            end
          end
        end
      end
    end

    initial_comment = ["# Strings extracted from toolbar yamls for gettext to find"]
    File.open(toolbar_strings_file, "w+") do |f|
      f.puts(initial_comment + gettext_strings.uniq.sort)
    end
  end
end
