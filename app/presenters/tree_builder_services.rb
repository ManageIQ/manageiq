class TreeBuilderServices < TreeBuilder
  # Services are returned in a tree - kids are discovered automatically

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
    all_services = Rbac.filtered(Service.where(:ancestry => [nil, ""]))
    if count_only
      all_services.size
    else
      MiqPreloader.preload(all_services.to_a, :picture)
      Service.arrange_nodes(all_services.sort_by { |n| [n.ancestry.to_s, n.name.downcase] })
    end
  end
end
