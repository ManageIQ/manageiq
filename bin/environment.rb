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

  def self.while_updating_bower
    # Run bower in a thread and continue to do the non-js stuff
    puts "Updating bower assets in parallel..."
    bower_thread = Thread.new { update_bower }

    yield

    bower_thread.join
    puts "Updating bower assets complete."
  end

  def self.install_bundler
    system!('gem install bundler --conservative')
  end

  def self.bundle_install
    system('bundle check') || system!('bundle install')
  end

  def self.bundle_update
    system!('bundle update')
  end

  def self.update_bower
    system!("bower update --allow-root -F --silent --config.analytics=false")
  end

  def self.system!(*args)
    system(*args) || abort("\n== Command #{args} failed ==")
  end
end
