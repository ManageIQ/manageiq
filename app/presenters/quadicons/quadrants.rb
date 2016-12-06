module Quadicons
  module Quadrants
    def self.quadrantize(type, record, context)
      if (klass = "Quadicons::Quadrants::#{type.to_s.camelize}".safe_constantize)
        klass.new(record, context)
      end
    end
  end
end
