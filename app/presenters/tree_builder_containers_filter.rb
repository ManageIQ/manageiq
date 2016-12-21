class TreeBuilderContainersFilter < TreeBuilder
  private

  def tree_init_options(_)
    {
      :leaf     => "Container",
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Containers"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(_count_only, _options)
    [
      {:id          => "global",
       :text        => _("Global Filters"),
       :image       => "100/folder.png",
       :tip         => _("Global Shared Filters"),
       :cfmeNoClick => true}
    ]
  end

  def x_get_tree_custom_kids(object, count_only, options)
    return count_only ? 0 : [] if object[:id] != "global"
    objects = MiqSearch.where(:db => options[:leaf]).visible_to_all
    count_only_or_objects(count_only, objects, 'description')
  end
end
