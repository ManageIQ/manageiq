module TreeNode
  class VmOrTemplate < Node
    set_attribute(:image) { "100/currentstate-#{@object.normalized_state.downcase}.png" }
    set_attribute(:tooltip) do
      unless @object.template?
        if @options.key?(:klass_name) && @options[:klass_name].constantize < TreeBuilderDatacenter
          _("VM: %{name}") % {:name => @object.name}
        else
          _("VM: %{name} (Click to view)") % {:name => @object.name}
        end
      end
    end
  end
end
