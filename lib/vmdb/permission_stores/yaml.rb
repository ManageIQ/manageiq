require 'psych'

module Vmdb
  module PermissionStores
    def self.create(config)
      YAML.new config.options[:filename]
    end

    class YAML
      def initialize(file)
        @permissions = Psych.load_file file
      end

      def can?(permission)
        @permissions.include? permission
      end
    end
  end
end
