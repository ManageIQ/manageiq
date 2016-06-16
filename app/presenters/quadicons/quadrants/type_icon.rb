module Quadicons
  module Quadrants
    class TypeIcon < Quadrants::Base
      def path
        "100/#{record_type_name}.png"
      end

      def record_type_name
        record.class.base_class.name.downcase.underscore
      end
    end
  end
end
