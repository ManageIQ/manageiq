module ActiveRecord
  class Base
    class << self
      alias base_model base_class

      def model_suffix
        self.name[self.base_model.name.length..-1]
      end
    end
  end
end
