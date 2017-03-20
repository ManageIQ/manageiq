class TreeBuilderServices < TreeBuilder
  # Services are returned in a tree - kids are discovered automatically

  private

  def tree_init_options(_tree_name)
    {
      :leaf     => "Service",
      :full_ids => true,
      :add_root => false
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = []
    objects.push(:id            => "asrv",
                 :text          => _("Active Services"),
                 :icon          => "pficon pficon-folder-close",
                 :load_children => true,
                 :tip           => _("Active Services"))
    objects.push(:id            => "rsrv",
                 :text          => _("Retired Services"),
                 :icon          => "pficon pficon-folder-close",
                 :load_children => true,
                 :tip           => _("Retired Services"))
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    services =
        if object[:id] == 'asrv'
          Rbac.filtered(Service.where("(retired IS NULL OR retired IS false) AND (ancestry is NULL or ancestry = '')"))
        else
          Rbac.filtered(Service.where(:retired => true, :ancestry => [nil, ""]))
        end
    if count_only
      services.size
    else
      MiqPreloader.preload(services.to_a, :picture)
      Service.arrange_nodes(services.sort_by { |n| [n.ancestry.to_s, n.name.downcase] })
    end
  end
end
