module Quadicons
  module Quadrants
    # Build a guest os Quadrant
    #
    class GuestOs < Quadrants::Base
      def path
        "100/os-#{os_image_name}.png"
      end

      def os_image_name
        if record.present? && record.respond_to?(:os_image_name)
          record.os_image_name.downcase
        else
          ""
        end
      end
    end
  end
end
