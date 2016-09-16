class TreeNodeBuilderBelongsToHac < TreeNodeBuilder

  def host_node(object)
    generic_node(object.name, "host.png", "#{ui_lookup(:table => "host")}: #{object.name}")
    @node[:hideCheckbox] = true
  end

  def generic_node(text, image, tip = nil)
    super
    @node[:cfmeNoClick]  = true
    @node[:checkable] = options[:checkable] if options.key?('checkable')
  end
end
