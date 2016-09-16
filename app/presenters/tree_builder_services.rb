class TreeBuilderServices < TreeBuilder
  has_kids_for Service, [:x_get_tree_service_kids]

  private

  def tree_init_options(_tree_name)
    {
      :leaf     => "Service",
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Services"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    roots = Rbac.filtered(Service.roots)

    # Define array of roots with children
    coalesce_func = Arel::Nodes::NamedFunction.new(
      "COALESCE",
      [Service.arel_table[:ancestry], Arel::Nodes::SqlLiteral.new("'0'")]
    ).as('bigint')
    cast_as_bigint_func = Arel::Nodes::NamedFunction.new("CAST", [coalesce_func])
    @root_nodes_with_kids = Service.where.not(:ancestry => nil)
                                   .where(cast_as_bigint_func.eq(Service.arel_table.project(:id)))
                                   .pluck(:id)

    # Preload the root service picture since it's called by TreeNodeBuilder#build
    MiqPreloader.preload(roots, :picture)

    count_only_or_objects(count_only, roots, "name")
  end

  def x_get_tree_service_kids(object, count_only)
    # Skip getting children if there are no children for a root node
    return unless object.ancestry || @root_nodes_with_kids.index(object.id)

    objects = Rbac.filtered(object.direct_service_children.select(&:display).sort_by { |o| o.name.downcase })
    count_only_or_objects(count_only, objects, 'name')
  end
end
