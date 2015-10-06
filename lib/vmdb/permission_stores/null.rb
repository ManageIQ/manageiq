module Vmdb
  module PermissionStores
    def self.create(_config)
      Null.new
    end

    class Null
      def can?(_permission)
        true
      end

      def supported_ems_type?(_type)
        true
      end
    end
  end
end
