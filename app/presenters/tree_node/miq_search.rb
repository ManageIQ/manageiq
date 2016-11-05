module TreeNode
  class MiqSearch < Node
    set_attribute(:title, &:description)
    set_attribute(:image, 'filter.png')
    set_attribute(:tooltip) { _("Filter: %{filter_description}") % {:filter_description => @object.description} }
  end
end
