class TreeNodeBuilderBelongsToHac < TreeNodeBuilder
  def generic_node(text, image, tip = nil)
    super
    if [ExtManagementSystem, EmsCluster, Datacenter, EmsFolder, ResourcePool].any? { |klass| object.kind_of?(klass) }
      @node[:select] = options.key?(:selected) && options[:selected].include?("#{object.class.name}_#{object[:id]}")
    end
    @node[:hideCheckbox] = true if object.kind_of?(Host)
    @node[:cfmeNoClick] = true
    @node[:checkable] = options[:checkable_checkboxes] if options.key?(:checkable_checkboxes)
  end
end
