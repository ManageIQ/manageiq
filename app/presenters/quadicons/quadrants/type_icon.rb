module Quadicons
  module Quadrants
    class TypeIcon < Quadrants::Base
      def path
        if record.decorator_class?
          decorator_icon
        else
          fallback_path
        end
      end

      def decorator_icon
        record.decorate.try(:quadicon_image_path) || record.decorate.try(:listicon_image)
      end

      def fallback_path
        "100/#{record_type_name}.png"
      end

      def record_type_name
        record.class.base_class.name.underscore.downcase
      end
    end
  end
end
