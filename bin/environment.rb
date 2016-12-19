require 'fileutils'
require 'pathname'

module Environment
  APP_ROOT = Pathname.new(File.expand_path('../../', __FILE__))

  def self.ensure_config_files
    config_files = {
      "certs/v2_key.dev"        => "certs/v2_key",
      "config/cable.yml.sample" => "config/cable.yml",
      "config/database.pg.yml"  => "config/database.yml",
    }

    config_files.each do |source, dest|
      file = APP_ROOT.join(dest)
      next if file.exist?
      puts "Copying #{file} from template..."
      FileUtils.cp(APP_ROOT.join(source), file)
    end
  end
end
