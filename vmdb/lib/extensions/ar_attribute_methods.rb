module ActiveRecord
  module AttributeMethods #:nodoc:
    def attribute_missing?(attr)
      !@attributes.has_key?(attr.to_s)
    end
  end
end
