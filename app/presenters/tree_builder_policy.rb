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

  # level 0 - root
  def root_options
    [N_("All Policies"), N_("All Policies")]
  end

  # level 1 - compliance & control
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

  # level 2 & 3...
  def x_get_tree_custom_kids(parent, options)
    assert_type(options[:type], :policy)

    # level 2 - host and vm under compliance/control
    if %w(compliance control).include?(parent[:id])
      pid = parent[:id]

      # Push folder node ids onto open_nodes array
      ["xx-#{pid}_xx-#{pid}-host", "xx-#{pid}_xx-#{pid}-vm"].each do |n|
        open_nodes = @tree_state.x_tree(options[:tree])[:open_nodes]
        open_nodes << n unless open_nodes.include?(n)
      end

      objects = [{:id => "#{pid}-host",
                  :text => "Host #{pid.capitalize} Policies",
                  :image => "host",
                  :tip => "Host Policies"},
                 {:id => "#{pid}-vm",
                  :text => "Vm #{pid.capitalize} Policies",
                  :image => "vm",
                  :tip => "Vm Policies"}]

      count_only_or_objects(options[:count_only], objects)
    # level 3 - actual policies
    elsif %w(host vm).include?(parent[:id].split('-').last)
      mode, towhat = parent[:id].split('-')

      objects = MiqPolicy.where(:mode   => mode.downcase,
                                :towhat => towhat.titleize)

      count_only_or_objects(options[:count_only], objects, :description)
    else
      # error checking
      super
    end
  end

  # level 4 - conditions & events for policy
  def x_get_tree_po_kids(parent, options)
    conditions = count_only_or_objects(options[:count_only], parent.conditions, :description)
    miq_events = count_only_or_objects(options[:count_only], parent.miq_event_definitions, :description)
    conditions + miq_events
  end

  # level 5 - actions under events
  def x_get_tree_ev_kids(parent, options)
    # TODO - need the policy from l3, not this
    pol_rec = parent.miq_policies.first

    success = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :success) : [])
    failure = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :failure) : [])
    success + failure
  end
end
