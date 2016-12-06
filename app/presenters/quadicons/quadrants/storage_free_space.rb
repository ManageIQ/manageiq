module Quadicons
  module Quadrants
    class StorageFreeSpace < Quadrants::Base
      def path
        "100/piecharts/datastore-#{usage}.png"
      end

      def usage
        if record.free_space_percent_of_total == 100
          20
        else
          ((record.free_space_percent_of_total.to_i + 2) / 5.25).round
        end
      end
    end
  end
end
