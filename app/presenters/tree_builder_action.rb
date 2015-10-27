class TreeBuilderAction < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ac_",
    )
  end

  # level 0 - root
  def root_options
    [t = N_("All Actions"), t]
  end

  # level 1 - actions
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, MiqAction.all, :description)
  end

  # level 2 - nothing
  def x_get_tree_ac_kids(_parent, count_only)
    count_only_or_objects(count_only, [])
  end
end
