module Quadicons
  module Quadrants
    class SnapshotCount < Quadrants::Base
      def render
        quadrant_tag do
          content_tag(:span, snapshot_count, :class => "quadrant-value")
        end
      end

      def snapshot_count
        h(record.try(:v_total_snapshots))
      end
    end
  end
end
