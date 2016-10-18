class TreeBuilderVandt < TreeBuilder
  include TreeBuilderArchived

  def tree_init_options(_tree_name)
    {:leaf => 'ManageIQ::Providers::InfraManager::VmOrTemplate'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true,
                  :allow_reselect => TreeBuilder.hide_vms)
  end

  def root_options
    [_("All VMs & Templates"), _("All VMs & Templates that I can see")]
  end

  def x_get_tree_roots(count_only, options)
    objects = count_only_or_objects_filtered(count_only, EmsInfra, "name", :match_via_descendants => VmOrTemplate)
    objects.collect! { |o| TreeBuilderVmsAndTemplates.new(o, options.dup).tree } unless count_only
    root_nodes = count_only_or_objects(count_only, x_get_tree_arch_orph_nodes("VMs and Templates"))

    objects + root_nodes
  end

  def x_get_child_nodes(id)
    model, _, prefix = self.class.extract_node_model_and_id(id)
    model == "Hash" ? super : find_child_recursive(x_get_tree_roots(false, {}), id)
  end

  private

  def find_child_recursive(children, id)
    children.each do |t|
      return t[:children] if t[:key] == id

      found = find_child_recursive(t[:children], id) if t[:children]
      return found unless found.nil?
    end
    nil
  end
end
