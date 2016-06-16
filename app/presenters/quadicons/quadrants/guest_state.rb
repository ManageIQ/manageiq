module Quadicons
  module Quadrants
    class GuestState < Quadrants::Base
      def path
        "72/currentstate-#{state}.png"
      end

      def state
        h(record.try(:normalized_state).try(:downcase))
      end

      private

      def default_tag_classes
        ["quadicon-quadrant", "guest_state-#{state}"] << css_class
      end
    end
  end
end
