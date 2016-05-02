class TreeBuilderPolicy < TreeBuilder
  has_kids_for MiqPolicy, [:x_get_tree_po_kids]
  has_kids_for MiqEventDefinition, [:x_get_tree_ev_kids, :parents]

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
    text_i18n = {:compliance => {:host            => N_("Host Compliance Policies"),
                                 :vm              => N_("Vm Compliance Policies"),
                                 :container_image => N_("Container Image Compliance Policies")},
                 :control    => {:host            => N_("Host Control Policies"),
                                 :vm              => N_("Vm Control Policies"),
                                 :container_image => N_("Container Image Control Policies")}}

    [{:id    => "#{pid}-host",
      :text  => text_i18n[pid.to_sym][:host],
      :image => "host",
      :tip   => N_("Host Policies")},
     {:id    => "#{pid}-vm",
      :text  => text_i18n[pid.to_sym][:vm],
      :image => "vm",
      :tip   => N_("Vm Policies")},
     {:id    => "#{pid}-containerImage",
      :text  => text_i18n[pid.to_sym][:container_image],
      :image => "container_image",
      :tip   => N_("Container Image Policies")
     }]
  end

  # level 0 - root
  def root_options
    [t = N_("All Policies"), t]
  end

  # level 1 - compliance & control
  def x_get_tree_roots(count_only, _options)
    # Push folder node ids onto open_nodes array
    %w(xx-compliance xx-control).each { |n| open_node(n) }

    objects = []
    objects << {:id => "compliance", :text => N_("Compliance Policies"), :image => "compliance", :tip => N_("Compliance Policies")}
    objects << {:id => "control", :text => N_("Control Policies"), :image => "control", :tip => N_("Control Policies")}

    count_only_or_objects(count_only, objects)
  end

  # level 2 & 3...
  def x_get_tree_custom_kids(parent, count_only, options)
    assert_type(options[:type], :policy)

    # level 2 - host and vm under compliance/control
    if %w(compliance control).include?(parent[:id])
      pid = parent[:id]

      # Push folder node ids onto open_nodes array
      %W(xx-#{pid}_xx-#{pid}-host xx-#{pid}_xx-#{pid}-vm xx-#{pid}_xx-#{pid}-containerImage).each { |n| open_node(n) }

      objects = compliance_control_kids(pid)
      count_only_or_objects(count_only, objects)
    # level 3 - actual policies
    elsif %w(host vm containerImage).include?(parent[:id].split('-').last)
      mode, towhat = parent[:id].split('-')

      objects = MiqPolicy.where(:mode   => mode.downcase,
                                :towhat => towhat.camelize)

      count_only_or_objects(count_only, objects, :description)
    else
      # error checking
      super
    end
  end

  # level 4 - conditions & events for policy
  def x_get_tree_po_kids(parent, count_only)
    conditions = count_only_or_objects(count_only, parent.conditions, :description)
    miq_events = count_only_or_objects(count_only, parent.miq_event_definitions, :description)
    conditions + miq_events
  end

  # level 5 - actions under events
  def x_get_tree_ev_kids(parent, count_only, parents)
    # the policy from level 3
    pol_rec = node_by_tree_id(parents.last)

    success = count_only_or_objects(count_only, pol_rec ? pol_rec.actions_for_event(parent, :success) : [])
    failure = count_only_or_objects(count_only, pol_rec ? pol_rec.actions_for_event(parent, :failure) : [])
    success + failure
  end
end
