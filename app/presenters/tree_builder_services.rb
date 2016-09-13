class TreeBuilderServices < TreeBuilder
  has_kids_for Hash,    [:x_get_tree_custom_kids]

  private

  def tree_init_options(_tree_name)
    {
      :leaf     => "Service",
      :lazy     => false,
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
    if count_only
      Rbac.filtered(Service.roots.where(:display => true)).size
    else
      all_services = Rbac.filtered(Service.where(:display => true))
      roots = Service.arrange_nodes(all_services.sort_by { |n| [n.ancestry.to_s, n.name.downcase] })
      MiqPreloader.preload(roots.keys, :picture)
      # array of a hash.
      roots.map { |n, v| { n => v} }
    end
  end

  # wish we didn't have to modify this.
  # tree builder is calling into this with the hash node
  # node_builder (via super) wants the service object
  # converting it across
  def x_build_single_node(object, pid, options)
    object = object.keys.first if object.kind_of?(Hash) # assuming this is just {service -> ...}
    super
  end

  def x_get_tree_custom_kids(object, count_only)
    # ancestry has leaf nodes as node => {}. present? clears out the empty node
    objects = object.values.select(&:present?)
    if count_only
      objects.size
    else
      # already sorted by name ?
      objects.map { |n, v| { n => v} }
    end
  end
end
