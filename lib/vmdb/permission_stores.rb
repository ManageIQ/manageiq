require "yaml"

module Vmdb
  class PermissionStores
    def self.instance
      @instance ||= new(blacklist)
    end

    def self.blacklist
      permission_files.flat_map { |file| YAML.load_file(file) }
    end

    private_class_method def self.permission_files
      Vmdb::Plugins.to_a.unshift(Rails)
        .map { |source| source.root.join("config", "permissions.yml") }
        .select(&:exist?)
    end

    attr_reader :blacklist

    def initialize(blacklist)
      @blacklist = blacklist
    end

    def can?(permission)
      blacklist.exclude?(permission.to_s)
    end

    def supported_ems_type?(type)
      can?("ems-type:#{type}")
    end
  end
end
