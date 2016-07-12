class TreeBuilderVandt < TreeBuilder
  include TreeBuilderArchived

  def tree_init_options(_tree_name)
    {:leaf => 'VmOrTemplate'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [_("All VMs & Templates"), _("All VMs & Templates that I can see")]
  end

  def x_get_tree_roots(count_only, options)
    objects = Rbac.filtered(EmsInfra.order("lower(name)"), :match_via_descendants => VmOrTemplate)

    if count_only
      objects.length + 2
    else
      objects = objects.to_a
      objects.collect! { |o| TreeBuilderVmsAndTemplates.new(o, options.dup).tree } +
        x_get_tree_arch_orph_nodes("VMs and Templates")
    end
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
