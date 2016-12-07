module TreeNode
  class << self
    # Options used:
    #   :type       -- Type of tree, i.e. :handc, :vandt, :filtered, etc
    #   :open_nodes -- Tree node ids of currently open nodes
    #   FIXME: fill in missing docs
    #
    def new(object, parent_id = nil, options = {})
      klass = "#{self}::#{object.class}"
      node = object.kind_of?(Hash) || Object.const_defined?(klass) ? klass : "#{self}::#{object.class.base_class}"
      node.constantize.new(object, parent_id, options)
    end
  end
end
