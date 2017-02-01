require 'fileutils'
require 'pathname'

module ManageIQ
  module Environment
    APP_ROOT = Pathname.new(__dir__).join("../..")

    def self.manageiq_plugin_setup
      install_bundler
      bundle_install

      ensure_config_files

      if ENV["CI"]
        write_region_file
        create_database_user
        setup_test_environment
      end
    end

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
      bower_thread.abort_on_exception = true

      yield

      bower_thread.join
      puts "Updating bower assets complete."
    end

    def self.install_bundler
      system!("echo 'gem: --no-ri --no-rdoc --no-document' > ~/.gemrc") if ENV['CI']
      system!("gem install bundler -v '#{bundler_version}' --conservative")
    end

    def self.bundle_install
      add_libcurl_path
      system('bundle check') || system!('bundle install')
    end

    def self.bundle_update
      add_libcurl_path
      system!('bundle update')
    end

    def self.create_database
      puts "\n== Updating database =="
      run_rake_task("db:create")
    end

    def self.migrate_database
      puts "\n== Updating database =="
      run_rake_task("db:migrate")
    end

    def self.seed_database
      puts "\n== Seeding database =="
      run_rake_task("db:seed GOOD_MIGRATIONS=skip")
    end

    def self.setup_test_environment
      puts "\n== Resetting tests =="
      run_rake_task("test:vmdb:setup")
    end

    def self.reset_automate_domain
      puts "\n== Resetting Automate Domains =="
      run_rake_task("evm:automate:reset")
    end

    def self.compile_assets
      puts "\n== Recompiling assets =="
      run_rake_task("evm:compile_assets")
    end

    def self.clear_logs_and_temp
      puts "\n== Removing old logs and tempfiles =="
      run_rake_task("log:clear tmp:clear")
    end

    def self.write_region_file(region_number = 1)
      File.write(APP_ROOT.join("REGION"), region_number.to_s)
    end

    def self.create_database_user
      system!(%q(psql -c "CREATE USER root SUPERUSER PASSWORD 'smartvm';" -U postgres))
    end

    def self.update_bower
      system!("bower update --allow-root -F --silent --config.analytics=false")
    end

    def self.bundler_version
      gemfile = APP_ROOT.join("Gemfile")
      File.read(gemfile).match(/gem\s+['"]bundler['"],\s+['"](.+?)['"]/)[1]
    end

    def self.run_rake_task(task)
      system!("#{APP_ROOT.join("bin/rails")} #{task}")
    end

    def self.system!(*args)
      system(*args, :chdir => APP_ROOT) || abort("\n== Command #{args} failed ==")
    end

    def self.add_libcurl_path
      # Skip if PKG_CONFIG_LIBDIR is already set
      unless ENV["PKG_CONFIG_LIBDIR"]
        # I would use sys-uname here, but since we can't assume that it has been
        # installed yet, using something that will #workGoodEnough™ from stdlib.
        if RbConfig::CONFIG['host_os'] =~ /darwin/
          # Check for homebrew install of curl
          curl_pkgconfig="/usr/local/opt/curl/lib/pkgconfig"
          if Dir.exists? curl_pkgconfig
            # Add to ENV if found
            ENV["PKG_CONFIG_LIBDIR"]=curl_pkgconfig
          else
            # Error with a helpful message if it doesn't exist
            raise <<-EOE.gsub(/^ */, '')
              📎  "Hey there!  Looks like you are having a bit of trouble! :)"

              Kidding aside, looks like you don't have PKG_CONFIG_LIBDIR set,
              or a valid place to find libcurl on OSX.  To install libcurl via
              homebrew so '#{  $0  }' will work without further changes
              necessary, run the following:

              $ brew install curl

              And rerun `#{$0}`.

              NOTE:  This will only provide libs for libcurl to be used for
              c-extensions, and will not replace your existing installation of
              `curl`.
            EOE
          end
        end
      end
    end
  end
end
