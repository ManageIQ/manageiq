module ActiveRecord
  class Base
    class << self
      alias base_model base_class

      def model_suffix
        name[base_model.name.length..-1]
      end
    end
  end
end
