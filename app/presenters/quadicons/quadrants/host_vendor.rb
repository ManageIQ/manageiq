module Quadicons
  module Quadrants
    # Build a guest os Quadrant
    #
    class HostVendor < Quadrants::Base
      def path
        "svg/vendor-#{vendor}.svg"
      end

      def vendor
        v = record.try(:vendor).try(:downcase) || "unknown"
        h(v)
      end
    end
  end
end
