class TreeBuilderCondition < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  # level 0 - root
  def root_options
    [t = _("All Conditions"), t]
  end

  # level 1 - host / vm
  def x_get_tree_roots(count_only, _options)
    text_i18n = {:Host                => N_("Host Conditions"),
                 :Vm                  => N_("VM and Instance Conditions"),
                 :ContainerReplicator => N_("Replicator Conditions"),
                 :ContainerGroup      => N_("Pod Conditions"),
                 :ContainerNode       => N_("Container Node Conditions"),
                 :ContainerImage      => N_("Container Image Conditions"),
                 :ExtManagementSystem => N_("Container Provider Conditions")}

    objects = MiqPolicyController::UI_FOLDERS.collect do |model|
      text = text_i18n[model.name.to_sym]
      {:id    => model.name.camelize(:lower),
       :image => model.name.underscore,
       :text  => text,
       :tip   => text}
    end
    count_only_or_objects(count_only, objects)
  end

  # level 2 - conditions
  def x_get_tree_custom_kids(parent, count_only, options)
    assert_type(options[:type], :condition)
    towhat = parent[:id].camelize
    return super unless MiqPolicyController::UI_FOLDERS.collect(&:name).include?(towhat)

    objects = Condition.where(:towhat => towhat)
    count_only_or_objects(count_only, objects, :description)
  end
end
