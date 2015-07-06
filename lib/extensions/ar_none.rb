module ActiveRecord
  class Base
    # TODO: Remove in Rails 4 as it is natively implemented
    def self.none
      where("1 = 0")
    end
  end
end
