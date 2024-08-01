# rubocop:disable Rails/RakeEnvironment

namespace :test do
  namespace :security do
    task :setup # NOOP - Stub for consistent CI testing

    desc "Run Brakeman with the specified report format ('human' or 'json')"
    task :brakeman, :format do |_, args|
      format = args.fetch(:format, "human")

      require "vmdb/plugins"
      require "brakeman"

      # Brakeman's engine_paths check does not work properly with engines
      require "brakeman/app_tree"
      require Rails.root.join('lib/extensions/brakeman_excludes_patch')
      Brakeman::AppTree.prepend(BrakemanExcludesPatch)

      app_path = Rails.root.to_s
      engine_paths = Vmdb::Plugins.paths.except(ManageIQ::Schema::Engine).values

      puts "** Running brakeman in #{app_path}"
      puts "**   engines:"
      puts "**   - #{engine_paths.join("\n**   - ")}"

      # See all possible options here:
      #   https://brakemanscanner.org/docs/brakeman_as_a_library/#using-options
      options = {
        :app_path     => app_path,
        :engine_paths => engine_paths,
        :quiet        => false,
        :pager        => false,
        :print_report => true
      }
      if format == "json"
        options[:output_files] = [
          Rails.root.join("log/brakeman.json").to_s,
          Rails.root.join("log/brakeman.log").to_s
        ]
      end

      tracker = Brakeman.run(options)

      exit 1 unless tracker.filtered_warnings.empty?
    end

    desc "Run bundle-audit with the specified report format ('human' or 'json')"
    task :bundle_audit, :format do |_, args|
      format = args.fetch(:format, "human")

      puts "** Running bundle-audit in #{Dir.pwd}"

      options = [:update, :verbose]
      if format == "json"
        options << {
          :format => "json",
          :output => Rails.root.join("log/bundle-audit.json").to_s
        }
      end

      require "awesome_spawn"
      cmd = AwesomeSpawn.build_command_line("bundle-audit check", options)
      puts "**   command: #{cmd}"

      exit $?.exitstatus unless system(cmd)
    end

    desc "Run yarn npm audit with the specified report format ('human' or 'json')"
    task :yarn_audit, :format do |_, args|
      format = args.fetch(:format, "human")

      require "vmdb/inflections"
      Vmdb::Inflections.load_inflections

      require "vmdb/plugins"
      engines = Vmdb::Plugins.ui_plugins
      engines = engines.select { |e| e.root.to_s == ENGINE_ROOT } if defined?(ENGINE_ROOT)

      FileUtils.rm_f(Rails.root.join("log/yarn-audit*.json"))

      success = engines.map do |engine|
        name = engine.module_parent.name.underscore.tr("/", "-")
        puts "\n** Running yarn npm audit for #{name}"
        path = engine.root
        puts "**   path:    #{path}"

        params = [:recursive, :no_deprecations, [:environment, "production"]] # TODO: Remove production and check all dependencies
        options = {:chdir => path}
        if format == "json"
          params << :json

          log_file = Rails.root.join("log/yarn-audit-#{name}.json")
          options[:out] = [log_file, "w"]
        end

        require "awesome_spawn"
        cmd = AwesomeSpawn.build_command_line("yarn npm audit", params)
        puts "**   command: #{cmd}"

        system(cmd, options)
      end.all?

      exit 1 unless success
    end
  end

  desc "Run all security tests with the specified report format ('human' or 'json')"
  task :security, :format do |_, args|
    format = args.fetch(:format, "human")
    ns = defined?(ENGINE_ROOT) ? "app:test:security" : "test:security"

    Rake::Task["#{ns}:bundle_audit"].invoke(format)
    puts
    Rake::Task["#{ns}:brakeman"].invoke(format)
    puts
    Rake::Task["#{ns}:yarn_audit"].invoke(format)
  end
end

# rubocop:enable Rails/RakeEnvironment
