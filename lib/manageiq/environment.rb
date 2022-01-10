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

      setup_test_environment(:task_prefix => 'app:', :root => plugin_root) unless ENV["SKIP_TEST_RESET"]

      prepare_codeclimate_test_reporter(plugin_root) if ENV["CI"]
    end

    def self.ensure_config_files
      config_files = {
        "certs/v2_key.dev"           => "certs/v2_key",
        "config/cable.yml.sample"    => "config/cable.yml",
        "config/database.pg.yml"     => "config/database.yml",
        "config/messaging.kafka.yml" => "config/messaging.yml",
      }

      config_files.each do |source, dest|
        file = APP_ROOT.join(dest)
        next if file.exist?
        puts "Copying #{file} from template..."
        FileUtils.cp(APP_ROOT.join(source), file)
      end
    end

    def self.update_ui_thread
      puts "\n== Updating UI assets (in parallel) =="

      ui_thread = Thread.new do
        update_ui
        puts "\n== Updating UI assets complete =="
      end

      ui_thread.abort_on_exception = true
      ui_thread
    end

    def self.install_bundler(root = APP_ROOT)
      system!("echo 'gem: --no-ri --no-rdoc --no-document' > ~/.gemrc") if ENV['CI']
      system!("gem install bundler -v '#{bundler_version}' --conservative")
      system!("bundle config path #{root.join('vendor/bundle').expand_path}", :chdir => root) if ENV["CI"]

      # For nokogiri 1.13.0+, native gem support was added, allowing pre-compiled binaries to be used.
      # This provides faster and more reliable installation but assumes you have total control of the installation environment.
      # On travis, or other CI's, we may not be able to easily install the various dev dependencies it expects.  We'll force
      # travis to compile these extensions from source until we can use these native gems.
      # See https://nokogiri.org/CHANGELOG.html#1130-2022-01-06
      system!("bundle config set force_ruby_platform true") if ENV["TRAVIS"]
    end

    def self.setup_gemfile_lock
      return if ENV["TRAVIS_BRANCH"] == "master"

      raise "Missing Gemfile.lock.release" unless APP_ROOT.join("Gemfile.lock.release").file?
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

    def self.prepare_codeclimate_test_reporter(root = APP_ROOT)
      system!("curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > ./cc-test-reporter", :chdir => root)
      system!("chmod +x ./cc-test-reporter", :chdir => root)
      system!("./cc-test-reporter before-build", :chdir => root)
    end

    def self.update_ui
      system!("bundle exec rake update:ui")
    end

    def self.bundler_version
      gemfile = APP_ROOT.join("Gemfile")

      require "bundler"
      gemfile_dependencies = Bundler::Definition.build(gemfile, nil, {}).dependencies
      bundler_dependency   = gemfile_dependencies.detect { |dep| dep.name == "bundler" }

      version_requirements = bundler_dependency.requirement.requirements
      version_requirements.map { |req| req.join(" ") }.join(", ")
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
