class TreeBuilderCondition < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "co_",
      :autoload  => true,
    )
  end

  # level 0 - root
  def root_options
    [t = N_("All Conditions"), t]
  end

  # level 1 - host / vm
  def x_get_tree_roots(options)
    objects = []
    objects << {:id => "host", :text => N_("Host Conditions"), :image => "host", :tip => N_("Host Conditions")}
    objects << {:id => "vm", :text => N_("All VM and Instance Conditions"), :image => "vm", :tip => N_("All VM and Instance Conditions")}

    count_only_or_objects(options[:count_only], objects)
  end

  # level 2 - conditions
  def x_get_tree_custom_kids(parent, options)
    assert_type(options[:type], :condition)
    return super unless %w(host vm).include?(parent[:id])

    objects = Condition.where(:towhat => parent[:id].titleize)

    count_only_or_objects(options[:count_only], objects, :description)
  end
end
