class TreeBuilderServiceCatalog < TreeBuilderCatalogsClass
  private

  def tree_init_options(tree_name)
    {:full_ids => true, :leaf => 'ServiceTemplateCatalog'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'svccat_',
      :autoload  => 'true',
    )
  end

  def x_get_tree_roots(options)
    objects = rbac_filtered_objects(ServiceTemplateCatalog.all).sort_by { |o| o.name.downcase }
    filtered_objects = []
    # only show catalogs nodes that have any servicetemplate records under them
    objects.each do |object|
      items = rbac_filtered_objects(object.service_templates)
      filtered_objects.push(object) unless items.empty?
    end
    count_only_or_objects(options[:count_only], filtered_objects, 'name')
  end

  def x_get_tree_stc_kids(object, options)
    objects = rbac_filtered_objects(object.service_templates.sort_by { |o| o.name.downcase })
    count_only_or_objects(options[:count_only], objects, 'name')
  end
end
