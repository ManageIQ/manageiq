class TreeBuilderVandt < TreeBuilder
  def tree_init_options(_tree_name)
    {:leaf => 'VmOrTemplate'}
  end

  def x_get_tree_roots(count_only, options)
    objects = rbac_filtered_objects(EmsInfra.order("lower(name)"), :match_via_descendants => VmOrTemplate)

    if count_only
      objects.length + 2
    else
      objects = objects.to_a
      objects.collect! { |o| TreeBuilderVmsAndTemplates.new(o, options).tree }
      objects + [
        {:id => "arch", :text => _("<Archived>"), :image => "currentstate-archived", :tip => _("Archived VMs and Templates")},
        {:id => "orph", :text => _("<Orphaned>"), :image => "currentstate-orphaned", :tip => _("Orphaned VMs and Templates")}
      ]
    end
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix         => "vt_",
      :no_getitem_alerts => true,
      :autoload          => true
    )
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, count_only, _options)
    objects = case object[:id]
              when "orph" # Orphaned
                rbac_filtered_objects(VmInfra.all_orphaned) +
                rbac_filtered_objects(TemplateInfra.all_orphaned)
              when "arch" # Archived
                rbac_filtered_objects(VmInfra.all_archived) +
                rbac_filtered_objects(TemplateInfra.all_archived)
              end
    count_only_or_objects(count_only, objects, "name")
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
