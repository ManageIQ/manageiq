module ActiveRecord
  class Base
    def number_of(assoc)
      @number_of ||= {}
      @number_of[assoc.to_sym] ||= send(assoc)&.size || 0
    end
  end
end
