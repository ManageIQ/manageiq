module Quadicons
  module Quadrants
    class HostCount < Quadrants::Base
      def render
        quadrant_tag do
          content_tag(:span, host_count, :class => "quadrant-value")
        end
      end

      # TODO: Abstract the count method with decorator
      def host_count
        record.try(:v_total_hosts)
      end
    end
  end
end
