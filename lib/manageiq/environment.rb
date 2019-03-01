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

    def self.warn_if_branch_out_of_date
      return if %w(production test).include?(ENV['RAILS_ENV'].to_s)

      Dir.chdir(APP_ROOT) do
        commits =
          if upstream_tracking_branch.empty?
            system!("git fetch upstream")
            commits_behind_upstream
          else
            system!("git fetch")
            commits_behind_tracked_branch
          end

        if commits.positive?
          warn "\n== Your branch is #{commits} commits out of date, please pull or fetch + merge."
        end
      end
    end

    def self.upstream_tracking_branch
      `git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD)`.strip
    end

    def self.commits_behind_tracked_branch
      # Show short status + branch information:
      # ## master...upstream/master [behind 10]
      # git 1.8.5+ shows upstream branch status, catch STDERR just in case
      command = 'git status -sb 2>&1 | grep -oE "\[behind.+\]" | grep -oE "[0-9]+"'
      `#{command}`.strip.to_i
    end

    def self.commits_behind_upstream
      # Assume your remote is called upstream, returns early if you're special
      `git branch -r | grep upstream`
      return 0 unless $?.exitstatus.zero?

      merge_base = `git merge-base upstream/master HEAD`.strip
      `git rev-list --count #{merge_base}..upstream/master`.strip.to_i
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
