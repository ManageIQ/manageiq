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
          content_dir = engine.root.join("content", "ansible_tmp")
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

    def content_directories(engine, subfolder)
      Dir.glob(engine.root.join("content", subfolder, "*"))
    end
  end
end
