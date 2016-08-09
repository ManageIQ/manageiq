module Quadicons
  module Quadrants
    class StorageType < Quadrants::Base
      def path
        "100/storagetype-#{type}.png"
      end

      def type
        if record.store_type.nil?
          "unknown"
        else
          h(record.store_type.to_s.try(:downcase))
        end
      end
    end
  end
end
