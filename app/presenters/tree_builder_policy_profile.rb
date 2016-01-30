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
    [t = N_("All Policy Profiles"), t]
  end

  # level 1 - policy profiles
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, MiqPolicySet.all, :description)
  end

  # level 2 - policies
  def x_get_tree_pp_kids(parent, count_only)
    count_only_or_objects(count_only,
                          parent.miq_policies,
                          ->(a) { a.towhat + a.mode + a.description.downcase })
  end

  # level 3 - conditions & events for policy
  def x_get_tree_po_kids(parent, count_only)
    conditions = count_only_or_objects(count_only, parent.conditions, :description)
    miq_events = count_only_or_objects(count_only, parent.miq_event_definitions, :description)
    conditions + miq_events
  end

  # level 4 - actions under events
  def x_get_tree_ev_kids(parent, count_only, parents)
    # the policy from level 2
    pol_rec = node_by_tree_id(parents.last)

    success = count_only_or_objects(count_only, pol_rec ? pol_rec.actions_for_event(parent, :success) : [])
    failure = count_only_or_objects(count_only, pol_rec ? pol_rec.actions_for_event(parent, :failure) : [])
    success + failure
  end

  # level 4 - nothing under conditions
  def x_get_tree_co_kids(_parent, count_only)
    count_only_or_objects(count_only, [])
  end

  # level 5 - nothing under actions
  def x_get_tree_ac_kids(_parent, count_only)
    count_only_or_objects(count_only, [])
  end
end
