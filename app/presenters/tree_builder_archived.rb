module TreeBuilderArchived
  def x_get_tree_custom_kids(object, count_only, options)
    klass = options[:leaf].safe_constantize
    objects = if TreeBuilder.hide_vms
                [] # hidden all VMs
              else
                case object[:id]
                when "orph" then  klass.all_orphaned
                when "arch" then  klass.all_archived
                end
              end
    count_only_or_objects_filtered(count_only, objects, "name")
  end

  def x_get_tree_arch_orph_nodes(model_name)
    [
      {:id => "arch", :text => _("<Archived>"), :image => "100/currentstate-archived.png", :tip => _("Archived %{model}") % {:model => model_name}},
      {:id => "orph", :text => _("<Orphaned>"), :image => "100/currentstate-orphaned.png", :tip => _("Orphaned %{model}") % {:model => model_name}}
    ]
  end
end
