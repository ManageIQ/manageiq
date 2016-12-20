class TreeBuilderPolicy < TreeBuilder
  has_kids_for MiqPolicy, [:x_get_tree_po_kids]
  has_kids_for MiqEventDefinition, [:x_get_tree_ev_kids, :parents]

  private

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :lazy     => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def compliance_control_kids(mode)
    text_i18n = {:compliance => {:Host                => N_("Host Compliance Policies"),
                                 :Vm                  => N_("Vm Compliance Policies"),
                                 :ContainerReplicator => N_("Replicator Compliance Policies"),
                                 :ContainerGroup      => N_("Pod Compliance Policies"),
                                 :ContainerNode       => N_("Container Node Compliance Policies"),
                                 :ContainerImage      => N_("Container Image Compliance Policies"),
                                 :ExtManagementSystem => N_("Provider Compliance Policies")},
                 :control    => {:Host                => N_("Host Control Policies"),
                                 :Vm                  => N_("Vm Control Policies"),
                                 :ContainerReplicator => N_("Replicator Control Policies"),
                                 :ContainerGroup      => N_("Pod Control Policies"),
                                 :ContainerNode       => N_("Container Node Control Policies"),
                                 :ContainerImage      => N_("Container Image Control Policies"),
                                 :ExtManagementSystem => N_("Provider Control Policies")}}

    MiqPolicyController::UI_FOLDERS.collect do |model|
      text = text_i18n[mode.to_sym][model.name.to_sym]
      {:id    => "#{mode}-#{model.name.camelize(:lower)}",
       :image => "100/#{model.name.underscore}.png",
       :text  => text,
       :tip   => text}
    end
  end

  # level 0 - root
  def root_options
    [t = _("All Policies"), t]
  end

  # level 1 - compliance & control
  def x_get_tree_roots(count_only, _options)
    objects = []
    objects << {:id => "compliance", :text => N_("Compliance Policies"), :image => "100/compliance.png", :tip => N_("Compliance Policies")}
    objects << {:id => "control", :text => N_("Control Policies"), :image => "100/control.png", :tip => N_("Control Policies")}

    # Push folder node ids onto open_nodes array
    objects.each { |o| open_node("xx-#{o[:id]}") }

    count_only_or_objects(count_only, objects)
  end

  # level 2 & 3...
  def x_get_tree_custom_kids(parent, count_only, options)
    assert_type(options[:type], :policy)

    # level 2 - host, vm, etc. under compliance/control
    if %w(compliance control).include?(parent[:id])
      mode = parent[:id]
      objects = compliance_control_kids(mode)

      return count_only_or_objects(count_only, objects)
    end

    # level 3 - actual policies
    mode, towhat = parent[:id].split('-')
    towhat = towhat.camelize
    if MiqPolicyController::UI_FOLDERS.collect(&:name).include?(towhat)
      objects = MiqPolicy.where(:mode => mode, :towhat => towhat)

      return count_only_or_objects(count_only, objects, :description)
    end

    # error checking
    super
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
