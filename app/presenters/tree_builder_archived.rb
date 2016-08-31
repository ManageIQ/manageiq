module TreeBuilderArchived
  def x_get_tree_custom_kids(object, count_only, options)
    klass  = Object.const_get(options[:leaf])
    method = case object[:id]
             when "orph" then :all_orphaned
             when "arch" then :all_archived
             end
    objects = Rbac.filtered(klass.send(method))
    count_only ? objects.length : objects
  end

  def x_get_tree_arch_orph_nodes(model_name)
    [
      {:id => "arch", :text => _("<Archived>"), :image => "currentstate-archived", :tip => _("Archived #{model_name}")},
      {:id => "orph", :text => _("<Orphaned>"), :image => "currentstate-orphaned", :tip => _("Orphaned #{model_name}")}
    ]
  end
end
