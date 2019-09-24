require 'fileutils'
require 'pathname'

module ManageIQ
  module Environment
    APP_ROOT = Pathname.new(__dir__).join("../..")

    def self.manageiq_plugin_setup(plugin_root = nil)
      # determine plugin root dir. Assume we are called from a 'bin/' script in the plugin root
      plugin_root ||= Pathname.new(caller_locations.last.absolute_path).dirname.parent

      manageiq_plugin_update(plugin_root)
    end

    def self.manageiq_plugin_update(plugin_root = nil)
      # determine plugin root dir. Assume we are called from a 'bin/' script in the plugin root
      plugin_root ||= Pathname.new(caller_locations.last.absolute_path).dirname.parent

      install_bundler(plugin_root)
      bundle_update(plugin_root)

      ensure_config_files

      create_database_user if ENV["CI"]

      setup_test_environment(:task_prefix => 'app:', :root => plugin_root)
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

      logdir = APP_ROOT.join("log")
      Dir.mkdir(logdir) unless Dir.exist?(logdir)
    end

    def self.while_updating_ui
      # Run update:ui in a thread and continue to do the non-js stuff
      puts "\n== Updating UI assets (in parallel) =="

      ui_thread = Thread.new do
        update_ui
        puts "\n== Updating UI assets complete =="
      end

      ui_thread.abort_on_exception = true

      yield

      ui_thread.join
    end

    def self.install_bundler(root = APP_ROOT)
      system!("echo 'gem: --no-ri --no-rdoc --no-document' > ~/.gemrc") if ENV['CI']
      system!("gem install bundler -v '#{bundler_version}' --conservative")
      system!("bundle config path #{root.join('vendor/bundle').expand_path}", :chdir => root) if ENV["CI"]
    end

    def self.bundle_update(root = APP_ROOT)
      system!("bundle update --jobs=3", :chdir => root)
      return unless ENV["CI"]
      lockfile_contents = File.read(root.join("Gemfile.lock"))
      puts "===== Begin Gemfile.lock =====\n\n#{lockfile_contents}\n\n===== End Gemfile.lock ====="
    end

    def self.create_database
      puts "\n== Updating database =="
      run_rake_task("db:create")
    end

    def self.migrate_database
      puts "\n== Migrating database =="
      run_rake_task("db:migrate")
    end

    def self.seed_database
      puts "\n== Seeding database =="
      run_rake_task("db:seed")
    end

    def self.setup_test_environment(task_prefix: '', root: APP_ROOT)
      puts "\n== Resetting tests =="
      run_rake_task("#{task_prefix}test:vmdb:setup", :root => root)
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

    def self.create_database_user
      system!(%q(psql -c "CREATE USER root SUPERUSER PASSWORD 'smartvm';" -U postgres))
    end

    def self.update_ui
      system!("bundle exec rake update:ui")
    end

    def self.bundler_version
      gemfile = APP_ROOT.join("Gemfile")
      File.read(gemfile).match(/gem\s+['"]bundler['"],\s+['"](.+?)['"]/)[1]
    end

    def self.run_rake_task(task, root: APP_ROOT)
      system!("bin/rails #{task}", :chdir => root)
    end

    def self.system!(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      options[:chdir] ||= APP_ROOT
      system(*args, options) || abort("\n== Command #{args} failed in #{options[:chdir]} ==")
    end
  end
end
