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

  def root_options
    [N_("All Events"), N_("All Events")]
  end

  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], MiqPolicy.all_policy_events, :description)
  end

  def x_get_tree_ev_kids(parent, options)
    # TODO - possibly wrong, used to be ..divined based on params[:id] and options[:parent_id] (see x_build_node in explorer.rb)
    pol_rec = parent.miq_policies.first

    success = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :success) : [])
    failure = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :failure) : [])
    success + failure
  end
end
