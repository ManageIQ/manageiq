class TreeNodeBuilderBelongsToVat < TreeNodeBuilder
  def ext_management_system_node
    super
    @node[:hideCheckbox] = true
  end

  def ems_folder_node
    super
    @node[:hideCheckbox] = true if object.kind_of?(Datacenter)
    @node[:select] = options[:selected].include?("EmsFolder_#{object[:id]}") unless object.kind_of?(Datacenter)
  end

  def blue?(object)
    if object.parent.present? &&
       object.parent.name == 'vm' &&
       object.parent.parent.present? &&
       object.parent.parent.kind_of?(Datacenter)
      true
    else
      object.parent.present? ? blue?(object.parent) : false
    end
  end

  def normal_folder_node
    if blue?(object)
      generic_node(object.name, "blue_folder.png", _("Folder: %{folder_name}") % {:folder_name => object.name})
    else
      generic_node(object.name, "folder.png", _("Folder: %{folder_name}") % {:folder_name => object.name})
      @node[:hideCheckbox] = true
    end
  end

  def cluster_node
    super
    @node[:hideCheckbox] = true
  end

  def generic_node(text, image, tip = nil)
    super
    @node[:cfmeNoClick] = true
    @node[:checkable] = options[:checkable] if options.key?(:checkable)
  end
end
