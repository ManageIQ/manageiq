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

  def compliance_control_kids(pid)
    text_i18n = {:compliance => {:host => N_("Host Compliance Policies"),
                                 :vm   => N_("Vm Compliance Policies")},
                 :control    => {:host => N_("Host Control Policies"),
                                 :vm   => N_("Vm Control Policies")}}

    [{:id    => "#{pid}-host",
      :text  => text_i18n[pid.to_sym][:host],
      :image => "host",
      :tip   => N_("Host Policies")},
     {:id    => "#{pid}-vm",
      :text  => text_i18n[pid.to_sym][:vm],
      :image => "vm",
      :tip   => N_("Vm Policies")}]
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
    objects << {:id => "compliance", :text => N_("Compliance Policies"), :image => "compliance", :tip => N_("Compliance Policies")}
    objects << {:id => "control", :text => N_("Control Policies"), :image => "control", :tip => N_("Control Policies")}

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

      objects = compliance_control_kids(pid)
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
    # the policy from level 3
    pol_rec = node_by_tree_id(options[:parents].last)

    success = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :success) : [])
    failure = count_only_or_objects(options[:count_only], pol_rec ? pol_rec.actions_for_event(parent, :failure) : [])
    success + failure
  end
end
