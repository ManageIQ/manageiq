class TreeBuilderServices < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {
      :leaf     => "Service",
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "svc_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, rbac_filtered_objects(Service.roots), "name")
  end

  def x_get_tree_service_kids(object, count_only)
    objects = rbac_filtered_objects(object.direct_service_children.select(&:display).sort_by { |o| o.name.downcase })
    count_only_or_objects(count_only, objects, 'name')
  end
end
