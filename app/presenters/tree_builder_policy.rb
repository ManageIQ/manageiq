class TreeBuilderPolicy < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "po_",
      :autoload  => true,
    )
  end

  def root_options
    [N_("All Policies"), N_("All Policies")]
  end

  def x_get_tree_roots(options)
    # Push folder node ids onto open_nodes array
    %w(xx-compliance xx-control).each do |n|
      open_nodes = @tree_state.x_tree(options[:tree])[:open_nodes]
      open_nodes << n unless open_nodes.include?(n)
    end

    objects = []
    objects << {:id => "compliance", :text => "Compliance Policies", :image => "compliance", :tip => "Compliance Policies"}
    objects << {:id => "control", :text => "Control Policies", :image => "control", :tip => "Control Policies"}

    count_only_or_objects(options[:count_only], objects)
  end

  def x_get_tree_po_kids(parent, options)
    conditions = count_only_or_objects(options[:count_only], parent.conditions, :description)
    miq_events = count_only_or_objects(options[:count_only], parent.miq_event_definitions, :description)
    conditions + miq_events
  end
end
