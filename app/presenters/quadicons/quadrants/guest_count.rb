module Quadicons
  module Quadrants
    class GuestCount < Quadrants::Base
      def render
        quadrant_tag do
          content_tag(:span, guest_count, :class => "quadrant-value")
        end
      end

      # TODO: Abstract the count method with decorator
      def guest_count
        record.try(:v_total_vms)
      end
    end
  end
end
