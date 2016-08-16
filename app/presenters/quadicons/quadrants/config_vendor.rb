module Quadicons
  module Quadrants
    class ConfigVendor < Quadrants::Base
      def path
        "vendor-#{config_vendor}"
      end

      def config_vendor
        record.try(:image_name)
      end
    end
  end
end
