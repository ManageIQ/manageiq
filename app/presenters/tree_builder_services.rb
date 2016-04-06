class TreeBuilderServices < TreeBuilder
  attr_accessor :index_nodes
  attr_accessor :root_id
  private

  def initialize(*args)
    @index_nodes, @root_id = x_get_tree_and_root_id
    super
  end

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

  def x_get_tree_and_root_id(options = {})
    objects = rbac_filtered_objects(nil, options.merge(:class => Service)).to_a
    MiqPreloader.preload(objects, [:service_template => {:picture => :binary_blob}])
    Service.index_nodes(objects)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, nodes(nil), "name")
  end

  def x_get_tree_service_kids(object, count_only)
    objects = nodes(object).select(&:display)
    count_only_or_objects(count_only, objects, 'name')
  end

  def nodes(parent_id)
    parent_id = parent_id.id if parent_id.respond_to?(:id)
    index_nodes[parent_id].try(:keys) || []
  end
end
