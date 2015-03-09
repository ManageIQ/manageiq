class TreeBuilderContainers < TreeBuilder
  private

  def tree_init_options(_)
    {
      :leaf     => "Container",
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "container_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], Container.all, "name")
  end
end
