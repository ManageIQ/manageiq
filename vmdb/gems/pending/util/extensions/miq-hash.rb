require 'more_core_extensions/core_ext/hash'

class Hash #:nodoc:
  unless method_defined?(:sort!)
    def sort!(*args, &block)
      sorted = sort(*args, &block)
      sorted = self.class[sorted.to_a] unless sorted.instance_of?(self.class)
      replace(sorted)
    end
  end

  unless method_defined?(:sort_by!)
    def sort_by!(*args, &block)
      sorted = sort_by(*args, &block)
      sorted = self.class[sorted.to_a] unless sorted.instance_of?(self.class)
      replace(sorted)
    end
  end
end
