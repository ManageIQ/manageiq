require 'singleton'

module Vmdb
  class Plugins
    include Singleton
    private_class_method :instance

    include Enumerable

    def self.method_missing(m, *args, &block)
      instance.respond_to?(m) ? instance.send(m, *args, &block) : super
    end

    def self.respond_to_missing?(*args)
      instance.respond_to?(*args)
    end

    def all
      @all ||=
        Rails::Engine.subclasses.select do |engine|
          engine.name.start_with?("ManageIQ::Providers::") || engine.try(:vmdb_plugin?)
        end.sort_by(&:name)
    end

    def each(&block)
      all.each(&block)
    end

    def init
      load_inflections
      register_models
    end

    def versions
      each_with_object({}) do |engine, hash|
        hash[engine] = version(engine)
      end
    end

    def ansible_content
      @ansible_content ||= begin
        require_relative 'plugins/ansible_content'
        flat_map do |engine|
          content_directories(engine, "ansible").map { |dir| AnsibleContent.new(dir) }
        end
      end
    end

    def ansible_runner_content
      @ansible_runner_content ||= begin
        map do |engine|
          content_dir = engine.root.join("content", "ansible_runner")
          next unless File.exist?(content_dir.join("requirements.yml"))

          [engine, content_dir]
        end.compact
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

    def system_automate_domains
      @system_automate_domains ||= automate_domains.select(&:system?)
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

    def load_inflections
      each do |engine|
        file = engine.root.join("config", "initializers", "inflections.rb")
        load file if file.exist?
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
    def version(engine)
      spec = bundler_specs_by_path[engine.root.to_s]

      case spec.source
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
      @bundler_specs_by_path ||= Bundler.environment.specs.index_by(&:full_gem_path)
    end

    def content_directories(engine, subfolder)
      Dir.glob(engine.root.join("content", subfolder, "*"))
    end
  end
end
