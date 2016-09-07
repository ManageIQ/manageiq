class TreeBuilderAction < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  # level 0 - root
  def root_options
    [t = N_("All Actions"), t]
  end

  # level 1 - actions
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, MiqAction.all, :description)
  end
end
