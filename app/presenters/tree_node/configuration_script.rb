module TreeNode
  class ConfigurationScript < Node
    set_attribute(:image, '100/configuration_script.png')
    set_attribute(:tooltip) { _("Ansible Tower Job Template: %{name}") % {:name => @object.name} }
  end
end
