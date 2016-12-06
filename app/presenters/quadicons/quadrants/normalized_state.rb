module Quadicons
  module Quadrants
    class NormalizedState < Quadrants::Base
      def path
        "72/currentstate-#{state}.png"
      end

      def state
        h(record.try(:normalized_state).try(:downcase))
      end

      private

      def default_tag_classes
        ["quadicon-quadrant", css_class, "normalized_state-#{state}"]
      end
    end
  end
end
