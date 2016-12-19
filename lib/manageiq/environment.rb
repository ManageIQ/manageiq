require 'fileutils'
require 'pathname'

module ManageIQ
  module Environment
    APP_ROOT = Pathname.new(File.expand_path('../../..', __FILE__))

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
      system!("echo 'gem: --no-ri --no-rdoc --no-document' > ~/.gemrc") if ENV['CI']
      system!("gem install bundler -v '#{bundler_version}' --conservative")
    end

    def self.bundle_install
      system('bundle check') || system!('bundle install')
    end

    def self.bundle_update
      system!('bundle update')
    end

    def self.create_database
      puts "\n== Updating database =="
      system!("#{APP_ROOT.join("bin/rails")} db:create")
    end

    def self.migrate_database
      puts "\n== Updating database =="
      system!("#{APP_ROOT.join("bin/rails")} db:migrate")
    end

    def self.seed_database
      puts "\n== Seeding database =="
      system!("#{APP_ROOT.join("bin/rails")} db:seed GOOD_MIGRATIONS=skip")
    end

    def self.setup_test_environment
      puts "\n== Resetting tests =="
      system!("#{APP_ROOT.join("bin/rails")} test:vmdb:setup")
    end

    def self.reset_automate_domain
      puts "\n== Resetting Automate Domains =="
      system!("#{APP_ROOT.join("bin/rails")} evm:automate:reset")
    end

    def self.compile_assets
      puts "\n== Recompiling assets =="
      system!("#{APP_ROOT.join("bin/rails")} evm:compile_assets")
    end

    def self.clear_logs_and_temp
      puts "\n== Removing old logs and tempfiles =="
      system!("#{APP_ROOT.join("bin/rails")} log:clear tmp:clear")
    end

    def self.update_bower
      system!("bower update --allow-root -F --silent --config.analytics=false")
    end

    def self.bundler_version
      gemfile = APP_ROOT.join("Gemfile")
      File.read(gemfile).match(/gem\s+['"]bundler['"],\s+['"](.+?)['"]/)[1]
    end

    def self.system!(*args)
      system(*args) || abort("\n== Command #{args} failed ==")
    end
  end
end
