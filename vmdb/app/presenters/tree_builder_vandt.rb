class TreeBuilderVandt < TreeBuilder
  def tree_init_options(tree_name)
    {:leaf => 'VmOrTemplate'}  # FIXME
  end

  def x_get_tree_roots(options)
    objects = rbac_filtered_objects(EmsInfra.order("lower(name)"), :match_via_descendants => "VmOrTemplate")

    if options[:count_only]
      objects.length + 2
    else
      objects.collect! { |o| TreeBuilderVmsAndTemplates.new(o, options).tree }
      objects + [
        {:id => "arch", :text => "<Archived>", :image => "currentstate-archived", :tip => "Archived VMs and Templates"},
        {:id => "orph", :text => "<Orphaned>", :image => "currentstate-orphaned", :tip => "Orphaned VMs and Templates"}
      ]
    end
  end

  def set_locals_for_render
    #binding.pry # @tree_nodes
    locals = super
    locals.merge!(
       #:tree_id => "vandt_treebox",
       #:tree_name => "vandt_tree",
       #:json_tree => @temp[:vandt_tree],
      :id_prefix => "vt_",
      #:onclick => "cfmeOnClick_SelectTreeNode",
      :select_node => "#{x_node(:vandt_tree)}",
      #:base_id => "root",
      #:no_base_exp => true,
      #:exp_tree => false,
      #:highlighting => true,
      #:tree_state => true,
      :no_getitem_alerts => true,
      # multi_lines ??
      :autoload => true
    )
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, options)
    objects = case object[:id]
              when "orph" # Orphaned
                rbac_filtered_objects(VmInfra.all_orphaned) +
                    rbac_filtered_objects(TemplateInfra.all_orphaned)
              when "arch" # Archived
                rbac_filtered_objects(VmInfra.all_archived) +
                    rbac_filtered_objects(TemplateInfra.all_archived)
              end
    count_only_or_objects(options[:count_only], objects, "name")
  end
end
