require 'psych'

module Vmdb
  module PermissionStores
    def self.create(config)
      YAML.new(config.options[:filename])
    end

    class YAML
      def initialize(file)
        @blacklist = Psych.load_file(file)
      end

      def can?(permission)
        !@blacklist.include?(permission)
      end

      def supported_ems_type?(type)
        can?("ems-type:#{type}")
      end
    end
  end
end
