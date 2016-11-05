module TreeNode
  class ConfiguredSystem < Node
    set_attribute(:title, &:hostname)
    set_attribute(:image, '100/configured_system.png')
    set_attribute(:tooltip) { _("Configured System: %{hostname}") % {:hostname => @object.hostname} }
  end
end
