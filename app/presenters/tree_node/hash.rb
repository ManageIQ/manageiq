module TreeNode
  class Hash < Node
    set_attribute(:title) { @object[:text].kind_of?(Proc) ? @object[:text].call : _(@object[:text]) }

    set_attribute(:image) { @object[:image] ? "100/#{@object[:image]}.png" : nil }

    set_attribute(:no_click) { @object.key?(:cfmeNoClick) && @object[:cfmeNoClick] }

    set_attribute(:hide_checkbox) { @object.key?(:hideCheckbox) && @object[:hideCheckbox] }

    set_attribute(:selected) { @object.key?(:select) && @object[:select] }

    set_attribute(:klass) { @object.key?(:addClass) ? @object[:addClass] : '' }

    set_attribute(:checkable) { @object[:checkable] != false }

    set_attribute(:tooltip) { @object[:tip] }
  end
end
