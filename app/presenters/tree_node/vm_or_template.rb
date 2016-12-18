module TreeNode
  class VmOrTemplate < Node
    set_attribute(:image) { "100/currentstate-#{@object.normalized_state.downcase}.png" }
    set_attribute(:tooltip) do
      unless @object.template?
        _("VM: %{name} (Click to view)") % {:name => @object.name}
      end
    end
  end
end
