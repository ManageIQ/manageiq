# rubocop:disable Rails/Output

require 'fileutils'
require 'pathname'

module ManageIQ
  module Environment
    APP_ROOT = Pathname.new(__dir__).join("../..")

    def self.manageiq_plugin_setup(plugin_root = nil)
      # determine plugin root dir. Assume we are called from a 'bin/' script in the plugin root
      plugin_root ||= Pathname.new(caller_locations.last.absolute_path).dirname.parent

      manageiq_plugin_update(plugin_root, force_bundle_update: false)
    end

    def self.manageiq_plugin_update(plugin_root = nil, force_bundle_update: true)
      # determine plugin root dir. Assume we are called from a 'bin/' script in the plugin root
      plugin_root ||= Pathname.new(caller_locations.last.absolute_path).dirname.parent

      ensure_config_files

      puts "== Installing dependencies =="
      setup_gemfile_lock if ci?
      install_bundler(plugin_root)
      bundle_config(plugin_root)
      bundle_update(plugin_root, force: force_bundle_update)

      unless skip_database_reset?
        # Update the local development database
        create_database(plugin_root)
        migrate_database(plugin_root)
        seed_database(plugin_root)
      end

      setup_test_environment(:task_prefix => 'app:', :root => plugin_root) unless skip_test_reset?
    end

    def self.ensure_config_files
      config_files = {
        "certs/v2_key.dev"        => "certs/v2_key",
        "config/cable.yml.sample" => "config/cable.yml",
        "config/database.pg.yml"  => "config/database.yml"
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
      # We can avoid installing bundler on two conditions:
      #   * The bundle command exists
      #   * Using it to retrieve the bundle's information on the bundler version is successful.
      #     This means the dependency tree is fully resolved and the currently active bundler's
      #     bundle executable is in the bundle and matches the dependency requirements.
      return if system("which bundle", [:out, :err] => "/dev/null") && system("bundle info bundler", [:out, :err] => "/dev/null", :chdir => root)

      system!("gem install bundler -v '#{bundler_version}' --conservative", :chdir => root)
    end

    def self.setup_gemfile_lock
      # Gemfile.lock.release only applies to non-master branches and PRs to non-master branches
      return unless ENV["GITHUB_REPOSITORY_OWNER"] == "ManageIQ" &&
                    ENV["GITHUB_BASE_REF"] != "master" && # PR to non-master branch
                    ENV["GITHUB_REF_NAME"] != "master" && # A non-master branch
                    !ENV["GITHUB_REF_NAME"].to_s.start_with?("revert-") &&     # GitHub's revert button makes branches in the primary repo
                    !ENV["GITHUB_REF_NAME"].to_s.start_with?("dependabot/") && # Dependabot makes branches in the primary repo
                    !ENV["GITHUB_REF_NAME"].to_s.start_with?("renovate/")      # Renovate makes branches in the primary repo

      raise "Missing Gemfile.lock.release" unless APP_ROOT.join("Gemfile.lock.release").file?

      FileUtils.cp(APP_ROOT.join("Gemfile.lock.release"), APP_ROOT.join("Gemfile.lock"))
    end

    def self.bundle_config(root = APP_ROOT)
      system!("bundle config set --local build.rugged --with-ssh", :chdir => root)
    end

    def self.bundle_update(root = APP_ROOT, force: false)
      if !force && system("bundle check", [:out, :err] => "/dev/null", :chdir => root)
        puts "== Bundle up to date... Skipping bundle update =="
      else
        system!("bundle update --jobs=3", :chdir => root)
      end
      return unless ci?

      lockfile_contents = File.read(root.join("Gemfile.lock"))
      puts "===== Begin Gemfile.lock =====\n\n#{lockfile_contents}\n\n===== End Gemfile.lock ====="
    end

    def self.create_database(root = APP_ROOT)
      puts "\n== Creating database =="
      run_rake_task("db:create", :root => root)
    end

    def self.migrate_database(root = APP_ROOT)
      puts "\n== Migrating database =="
      run_rake_task("db:migrate", :root => root)
    end

    def self.seed_database(root = APP_ROOT)
      puts "\n== Seeding database =="
      run_rake_task("db:seed", :root => root)
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

    def self.ci?
      ENV.fetch("CI", nil) == "true"
    end

    def self.skip_database_reset?
      ENV.key?("SKIP_DATABASE_RESET") ? ENV.fetch("SKIP_DATABASE_RESET") == "true" : ci?
    end

    def self.skip_test_reset?
      ENV.fetch("SKIP_TEST_RESET", nil) == "true"
    end
  end
end

# rubocop:enable Rails/Output
