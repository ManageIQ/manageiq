class TreeNodeBuilderBelongsToHac < TreeNodeBuilder
  def ext_management_system_node
    super
    @node[:select] = options[:selected].include?("#{object.class.name}_#{object[:id]}")
  end

  def host_node(object)
    super
    @node[:hideCheckbox] = true
  end

  def cluster_node
    super
    @node[:select] = options.key?(:selected) && options[:selected].include?("EmsCluster_#{object[:id]}")
  end

  def ems_folder_node
    super
    if object.kind_of?(Datacenter)
      @node[:select] = options[:selected].include?("Datacenter_#{object[:id]}")
    else
      @node[:select] = options.key?(:selected) && options[:selected].include?("EmsFolder_#{object[:id]}")
    end
  end

  def resource_pool_node
    super
    @node[:select] = options.key?(:selected) && options[:selected].include?("ResourcePool_#{object[:id]}")
  end

  def generic_node(text, image, tip = nil)
    super
    @node[:cfmeNoClick] = true
    @node[:checkable] = options[:checkable_checkboxes] if options.key?(:checkable_checkboxes)
  end
end
