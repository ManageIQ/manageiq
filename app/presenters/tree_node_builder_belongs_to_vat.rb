class TreeNodeBuilderBelongsToVat < TreeNodeBuilder
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

  def generic_node(text, image, tip = nil)
    super
    @node[:cfmeNoClick] = true
    @node[:checkable] = options[:checkable_checkboxes] if options.key?(:checkable_checkboxes)
    if [ExtManagementSystem, EmsCluster, Datacenter].any? { |klass| object.kind_of?(klass) }
      @node[:hideCheckbox] = true
    end
    if object.kind_of?(EmsFolder)
      if blue?(object)
        @node[:icon] = ActionController::Base.helpers.image_path("100/blue_folder.png")
      else
        @node[:hideCheckbox] = true
      end
      @node[:select] = options.key?(:selected) && options[:selected].include?("EmsFolder_#{object[:id]}")
    end
  end
end
