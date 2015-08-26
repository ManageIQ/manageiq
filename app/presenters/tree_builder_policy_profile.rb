class TreeBuilderPolicyProfile < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "pp_",
      :autoload  => true,
    )
  end

  # level 0 - root
  def root_options
    [N_("All Policy Profiles"), N_("All Policy Profiles")]
  end

  # level 1 - policy profiles
  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], MiqPolicySet.all, :description)
  end

  # level 2 - policies
  def x_get_tree_pp_kids(parent, options)
    count_only_or_objects(options[:count_only],
                          parent.miq_policies,
                          lambda { |a| a.towhat + a.mode + a.description.downcase })
  end

  # level 3 - conditions & events for policy
  def x_get_tree_po_kids(parent, options)
    conditions = count_only_or_objects(options[:count_only], parent.conditions, :description)
    miq_events = count_only_or_objects(options[:count_only], parent.miq_event_definitions, :description)
    conditions + miq_events
  end

  # level 4 - actions under events
  def x_get_tree_ev_kids(parent, options)
    # the policy from level 2
    pol_rec = node_by_tree_id(options[:parents].last)

    success = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :success) : [])
    failure = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :failure) : [])
    success + failure
  end
end
