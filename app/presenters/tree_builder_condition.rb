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

  def root_options
    [N_("All Conditions"), N_("All Conditions")]
  end

  def x_get_tree_roots(options)
    objects = []
    objects << {:id => "host", :text => "Host Conditions", :image => "host", :tip => "Host Conditions"}
    objects << {:id => "vm", :text => "All VM and Instance Conditions", :image => "vm", :tip => "All VM and Instance Conditions"}

    count_only_or_objects(options[:count_only], objects)
  end
end
