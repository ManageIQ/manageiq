module TreeNode
  class << self
    def new(object, parent_id = nil, options = {})
      klass = "#{self}::#{object.class}"
      node = Object.const_defined?(klass) ? klass : "#{self}::#{object.class.base_class}"
      node.constantize.new(object, parent_id, options)
    end
  end
end
