require 'fileutils'
require 'pathname'

module ManageIQ
  module Environment
    APP_ROOT = Pathname.new(__dir__).join("../..").expand_path

    def self.check_cli_options
      return if ARGV.empty?

      STDERR.puts <<~EOS
        Usage: bin/update

        Environment Variable Options:
          SKIP_DATABASE_SETUP  Skip the creation, migration, and seeding of the database.
          SKIP_UI_UPDATE       Skip the update of UI assets.
          SKIP_AUTOMATE_RESET  Skip the reset of the automate domain.
          SKIP_TEST_RESET      Skip the creation of the test enviroment.  Defaults to
                               true in production mode since the tasks do not exist.
      EOS

      help_requested = ARGV.size == 1 && %w[--help -h].include?(ARGV.first)
      exit help_requested ? 0 : 1
    end

    def self.manageiq_plugin_setup(plugin_root)
      manageiq_plugin_update(plugin_root)
    end

    def self.manageiq_plugin_update(plugin_root)
      Dir.chdir(plugin_root) do
        system!("bin/before_install")
        bundle_update
        ensure_config_files
        setup_test_database(:task_prefix => 'app:')
      end
    end

    def self.manageiq_core_setup
      manageiq_core_update
    end

    def self.manageiq_core_update
      if ENV["CI"]
        ENV["SKIP_DATABASE_SETUP"] = "true"  # No need for dev database in test
        ENV["SKIP_UI_UPDATE"] = "true"       # No need for assets in test
        ENV["SKIP_AUTOMATE_RESET"] = "true"  # No dev database to reset into in test
      end

      ENV["SKIP_TEST_RESET"] = "true" if ENV["RAILS_ENV"] == "production"

      Dir.chdir(APP_ROOT) do
        bundle_update
        ensure_config_files
        update_ui_thread do
          setup_database
          setup_test_database
          reset_automate_domain
        end
        compile_assets if ENV['RAILS_ENV'] == 'production'
        clear_logs_and_temp
      end
    end

    def self.ensure_config_files
      logging("Ensuring config files") do
        {
          "certs/v2_key.dev"           => "certs/v2_key",
          "config/cable.yml.sample"    => "config/cable.yml",
          "config/database.pg.yml"     => "config/database.yml",
          "config/messaging.kafka.yml" => "config/messaging.yml",
        }.each do |source, dest|
          file = APP_ROOT.join(dest)
          next if file.exist?

          puts "Copying #{file} from template..."
          FileUtils.cp(APP_ROOT.join(source), file)
        end
      end
    end

    def self.bundle_update
      if ENV["CI"]
        # In CI, bundle install is handled by setup-ruby, so just log the lockfiles
        %w[Gemfile.lock yarn.lock].each do |lockfile|
          logging(lockfile) do
            if File.exist?(lockfile)
              puts File.read(lockfile)
            else
              puts "#{lockfile} does not exist"
            end
          end
        end
      else
        logging("Updating bundle") do
          system!("gem install bundler -v '#{bundler_version}' --conservative")
          system!("bundle update --jobs=3")
        end
      end
    end

    def self.setup_database
      return if ENV["SKIP_DATABASE_SETUP"]

      logging("Updating database") do
        system!("bin/rails db:create db:migrate db:seed")
      end
    end

    def self.setup_test_database(task_prefix: '')
      return if ENV["SKIP_TEST_RESET"]

      logging("Resetting test environment") do
        system!("bin/rails #{task_prefix}test:vmdb:setup")
      end
    end

    def self.reset_automate_domain
      return if ENV["SKIP_AUTOMATE_RESET"]

      logging("Resetting Automate Domains") do
        system!("bin/rails evm:automate:reset")
      end
    end

    def self.compile_assets
      logging("Compiling UI assets") do
        system!("bin/rails evm:compile_assets")
      end
    end

    def self.clear_logs_and_temp
      logging("Removing old logs and tempfiles") do
        system!("bin/rails log:clear tmp:clear")
      end
    end

    def self.update_ui_thread
      ui_thread = Thread.new { update_ui(parallel: true) }
      ui_thread.abort_on_exception = true
      yield
      ui_thread.join
    end

    def self.update_ui(parallel: false)
      return if ENV["SKIP_UI_UPDATE"]

      logging("Updating UI assets #{"(in parallel)" if parallel}") do
        system!("bin/rails update:ui")
      end
    end

    def self.bundler_version
      gemfile = APP_ROOT.join("Gemfile")

      require "bundler"
      gemfile_dependencies = Bundler::Definition.build(gemfile, nil, {}).dependencies
      bundler_dependency   = gemfile_dependencies.detect { |dep| dep.name == "bundler" }

      version_requirements = bundler_dependency.requirement.requirements
      version_requirements.map { |req| req.join(" ") }.join(", ")
    end

    def self.logging(title)
      puts ENV["CI"] ? "::group::#{title}" : "== #{title} =="
      yield
    ensure
      puts "::endgroup::" if ENV["CI"]
    end

    def self.system!(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      options[:chdir] ||= APP_ROOT
      system(*args, options) || abort("\n== Command #{args} failed in #{options[:chdir]} ==")
    end
  end
end
