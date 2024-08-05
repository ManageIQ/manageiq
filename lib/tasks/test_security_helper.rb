# rubocop:disable Rails/Output

class TestSecurityHelper
  class SecurityTestFailed < StandardError; end

  def self.brakeman(format: "human")
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

    raise SecurityTestFailed unless tracker.filtered_warnings.empty?
  end

  def self.bundle_audit(format: "human")
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

    raise SecurityTestFailed unless system(cmd)
  end

  def self.yarn_audit(format: "human")
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

    raise SecurityTestFailed unless success
  end

  def self.all(format: "human")
    brakeman(format: format)
    puts
    bundle_audit(format: format)
    puts
    yarn_audit(format: format)
    true
  end

  def self.rebuild_yarn_audit_pending
    raise "Expected to be called from an engine" unless defined?(ENGINE_ROOT)

    require "pathname"
    require "json"
    require "more_core_extensions/core_ext/array/tableize"

    yarnrc_yml = Pathname.new(ENGINE_ROOT).join(".yarnrc.yml")
    yarnrc = yarnrc_yml.readlines
    start_index = yarnrc.index("npmAuditExcludePackages:\n")
    end_index = yarnrc[start_index..].index("\n") + start_index
    yarnrc.slice!(start_index + 1...end_index)
    yarnrc_yml.write(yarnrc.join)

    output = `yarn npm audit --recursive --no-deprecations --environment production --json`

    lines =
      output
      .chomp
      .lines
      .map { |l| JSON.parse(l) }
      .group_by { |h| h["value"] }
      .transform_keys { |k| "- #{k}\n" }
      .transform_values do |values|
        values = values.map do |h|
          [
            "pending",
            h.dig("children", "Severity"),
            h.dig("children", "URL").sub("https://github.com/advisories/", ""),
            "#{h["value"]} #{h.dig("children", "Vulnerable Versions")}",
            "#{h.dig("children", "Tree Versions").join(", ")} brought in by #{h.dig("children", "Dependents").join(", ")}"
          ]
        end

        values
        .tableize(:header => false)
        .lines
        .map { |l| l.sub(/^ /, "# ") }
      end
      .flatten(2)

    yarnrc.insert(start_index + 1, lines)
    yarnrc_yml.write(yarnrc.join)
  end
end

# rubocop:enable Rails/Output
