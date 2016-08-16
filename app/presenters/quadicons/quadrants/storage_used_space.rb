module Quadicons
  module Quadrants
    class StorageUsedSpace < Quadrants::Base
      def path
        "100/piecharts/datastore-#{usage}.png"
      end

      def usage
        (record.used_space_percent_of_total.to_i + 9) / 10
      end
    end
  end
end
