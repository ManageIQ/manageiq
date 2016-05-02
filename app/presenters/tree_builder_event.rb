class TreeBuilderEvent < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ev_",
    )
  end

  # level 0 - root
  def root_options
    [t = N_("All Events"), t]
  end

  # level 1 - events
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, MiqPolicy.all_policy_events, :description)
  end
end
