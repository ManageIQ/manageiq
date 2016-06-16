module Quadicons
  module Quadrants
    # Build a guest os Quadrant
    #
    class HostVendor < Quadrants::Base
      def path
        "svg/vendor-#{vendor}.svg"
      end

      def vendor
        h(record.try(:vendor).try(:downcase))
      end
    end
  end
end
