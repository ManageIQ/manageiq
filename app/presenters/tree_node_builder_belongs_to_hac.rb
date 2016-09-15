class TreeNodeBuilderBelongsToHac < TreeNodeBuilder

  def host_node(object)
    generic_node(object.name, "host.png", "#{ui_lookup(:table => "host")}: #{object.name}")
    @node[:hideCheckbox] = true
  end
end