module ActiveRecord
  class Base
    def number_of(assoc)
      @number_of ||= {}
      @number_of[assoc.to_sym] ||= self.send(assoc).size
    end
  end
end
