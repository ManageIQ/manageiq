require 'singleton'

module Vmdb
  class Plugins
    include Singleton
    private_class_method :instance

    include Enumerable

    def self.method_missing(m, ...)
      instance.respond_to?(m) ? instance.send(m, ...) : super
    end

    def self.respond_to_missing?(*args)
      instance.respond_to?(*args)
    end

    def all
      @all ||= Rails::Engine.subclasses.select { |engine| engine.try(:vmdb_plugin?) }.sort_by(&:name)
    end

    def each(&block)
      all.each(&block)
    end

    def init
      load_inflections
      init_loggers
      register_models
    end

    def details
      each_with_object({}) do |engine, hash|
        hash[engine] = {
          :name    => engine.name,
          :version => version(engine),
          :path    => engine.root.to_s
        }
      end
    end

    def paths
      details.transform_values { |v| v[:path] }
    end

    def versions
      details.transform_values { |v| v[:version] }
    end

    def plugin_for_class(klass)
      klass = klass.to_s unless klass.kind_of?(String)

      klass_path, _klass_line = Object.const_source_location(klass)
      return unless klass_path

      paths.detect { |_engine, path| klass_path.start_with?(path) }&.first
    end

    # Ansible content (roles) that come out-of-the-box, for use by both Automate
    #   and ansible-runner
    def ansible_content
      @ansible_content ||= begin
        require_relative 'plugins/ansible_content'
        flat_map do |engine|
          content_directories(engine, "ansible").map { |dir| AnsibleContent.new(dir) }
        end
      end
    end

    # Ansible content (playbooks and roles) for internal use by provider plugins,
    #   not exposed to Automate, and to be run by ansible_runner
    def ansible_runner_content
      @ansible_runner_content ||= begin
        map do |engine|
          content_dir = engine.root.join("content", "ansible_runner")
          next unless File.exist?(content_dir.join("roles/requirements.yml"))

          [engine, content_dir]
        end.compact
      end
    end

    def embedded_workflows_content
      @embedded_workflows_content ||= index_with do |engine|
        engine.root.join("content", "workflows").glob("**/*.asl")
      end
    end

    def automate_domains
      @automate_domains ||= begin
        require_relative 'plugins/automate_domain'
        flat_map do |engine|
          content_directories(engine, "automate").map { |dir| AutomateDomain.new(dir) }
        end
      end
    end

    def miq_widgets_content
      @miq_widgets_content ||= Dir.glob(Rails.root.join("product/dashboard/widgets/*")) + flat_map { |engine| content_directories(engine, "dashboard/widgets") }
    end

    def provider_plugins
      @provider_plugins ||= select { |engine| engine.name.start_with?("ManageIQ::Providers::") }
    end

    def asset_paths
      @asset_paths ||= begin
        require_relative 'plugins/asset_path'
        map { |engine| AssetPath.new(engine) if AssetPath.asset_path?(engine) }.compact
      end
    end

    def server_role_paths
      @server_role_paths ||= filter_map do |engine|
        file = engine.root.join("config/server_roles.csv")
        file if file.exist?
      end
    end

    def systemd_units
      @systemd_units ||= begin
        flat_map { |engine| engine.root.join("systemd").glob("*.*") }
      end
    end

    def load_inflections
      each do |engine|
        file = engine.root.join("config", "initializers", "inflections.rb")
        load file if file.exist?
      end
    end

    def init_loggers
      each do |engine|
        engine.try(:init_loggers)
      end
    end

    def register_models
      each do |engine|
        # make sure STI models are recognized
        DescendantLoader.instance.descendants_paths << engine.root.join('app')
      end
    end

    private

    # Determine the version of the specified engine
    #
    # If the gem is
    # - git based, pointing to a branch:   <branch>@<sha>
    # - git based, pointing to a tag:      <tag>@<sha>
    # - git based, pointing to a sha:      <sha>
    # - path based, with git, on a branch: <branch>@<sha>
    # - path based, with git, on a tag:    <tag>@<sha>
    # - path based, with git, on a sha:    <sha>
    # - path based, without git:           nil
    # - a real gem:                        <gem_version>
    #
    # The paths above can be real paths or symlinked paths.
    def version(engine)
      spec = bundler_specs_by_path[engine.root.realpath.to_s]

      case spec&.source
      when Bundler::Source::Git
        [
          spec.source.branch || spec.source.options["tag"],
          spec.source.revision.presence[0, 8]
        ].compact.join("@").presence
      when Bundler::Source::Path
        if engine.root.join(".git").exist?
          branch = sha = nil
          Dir.chdir(engine.root) do
            branch   = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip.presence
            branch   = nil if branch == "HEAD"
            branch ||= `git describe --tags --exact-match HEAD 2>/dev/null`.strip.presence

            sha = `git rev-parse HEAD 2>/dev/null`.strip[0, 8].presence
          end

          [branch, sha].compact.join("@").presence
        end
      when Bundler::Source::Rubygems
        spec.version
      end
    end

    def bundler_specs_by_path
      # NOTE: The rescue nil / delete nil dance is needed because of a bundler
      # bug where on Ruby 2.5 the full_gem_path is a nonexistent directory for
      # gems that are also default gems.
      # See https://github.com/bundler/bundler/issues/6930.
      @bundler_specs_by_path ||= Bundler.load.specs.index_by { |s| File.realpath(s.full_gem_path) rescue nil }.tap { |s| s.delete(nil) }
    end

    def content_directories(engine, subfolder)
      Dir.glob(engine.root.join("content", subfolder, "*"))
    end
  end
end
