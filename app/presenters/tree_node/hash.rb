module TreeNode
  class Hash < Node
    set_attribute(:title) { @object[:text].kind_of?(Proc) ? @object[:text].call : _(@object[:text]) }

    set_attribute(:image) { @object[:image] }

    set_attribute(:no_click) { @object.key?(:cfmeNoClick) && @object[:cfmeNoClick] ? true : nil }

    set_attribute(:hide_checkbox) { @object.key?(:hideCheckbox) && @object[:hideCheckbox] ? true : nil }

    set_attribute(:selected) { @object.key?(:select) && @object[:select] ? true : nil }

    set_attribute(:klass) { @object.key?(:addClass) ? @object[:addClass] : nil }

    set_attribute(:checkable) { @object[:checkable] != false ? true : nil }

    set_attribute(:tooltip) { @object[:tip] }

    set_attribute(:key) do
      if @object[:id] == "-Unassigned"
        "-Unassigned"
      else
        prefix = TreeBuilder.get_prefix_for_model("Hash")
        "#{@options[:full_ids] && !@parent_id.blank? ? "#{@parent_id}_" : ''}#{prefix}-#{@object[:id]}"
      end
    end
  end
end
