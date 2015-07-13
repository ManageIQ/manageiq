module TreeBuilderArchived
  def x_get_tree_custom_kids(object, options)
    klass  = Object.const_get(options[:leaf])
    method = case object[:id]
             when "orph" then :all_orphaned
             when "arch" then :all_archived
             end
    objects = rbac_filtered_objects(klass.send(method))
    options[:count_only] ? objects.length : objects
  end
end
