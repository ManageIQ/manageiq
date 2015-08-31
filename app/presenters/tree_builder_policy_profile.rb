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

  def root_options
    [N_("All Policy Profiles"), N_("All Policy Profiles")]
  end

  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], MiqPolicySet.all, :description)
  end

  def x_get_tree_pp_kids(parent, options)
    count_only_or_objects(options[:count_only],
                          parent.miq_policies,
                          lambda { |a| a.towhat + a.mode + a.description.downcase })
  end
end
