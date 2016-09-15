class TreeNodeBuilderBelongsToVat < TreeNodeBuilder
  def ext_management_system
    super
    @node[:hideCheckbox] = true
  end

  def ems_folder_node
    super
    @node[:hideCheckbox] = true if object.kind_of?(Datacenter)
  end

  def normal_folder_node
    generic_node(object.name, "blue_folder" , _("Folder: %{folder_name}") % {:folder_name => object.name})
  end

  def cluster_node
    super
    @node[:hideCheckbox] = true
  end

end