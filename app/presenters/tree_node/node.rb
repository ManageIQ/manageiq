module TreeNode
  class Node < NodeBuilder
    set_attribute(:title, &:name)
    set_attribute(:tooltip, nil)
    set_attribute(:expand) do
      @options[:open_all].present? && @options[:open_all] && @options[:expand] != false
    end
    set_attribute(:hide_checkbox) do
      @options.key?(:hideCheckbox) && @options[:hideCheckbox]
    end
  end
end
