module Vmdb
  module PermissionStores
    def self.create(config)
      Null.new
    end

    class Null
      def can?(permission)
        true
      end

      def supported_ems_type?(type)
        true
      end
    end
  end
end
