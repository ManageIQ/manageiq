class TreeBuilderImages < TreeBuilder
  def tree_init_options(_tree_name)
    {
      :leaf => "TemplateCloud"
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "images_treebox",
      :tree_name => "images_tree",
      :id_prefix => "images_",
      :autoload  => true
    )
  end

  def x_get_tree_roots(options)
    objects = rbac_filtered_objects(EmsCloud.order("lower(name)"), :match_via_descendants => "TemplateCloud")
    objects += [
      {:id => "arch", :text => "<Archived>", :image => "currentstate-archived", :tip => "Archived Images"},
      {:id => "orph", :text => "<Orphaned>", :image => "currentstate-orphaned", :tip => "Orphaned Images"}
    ]
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_ems_kids(object, options)
    objects = rbac_filtered_objects(object.miq_templates.order("name"))
    options[:count_only] ? objects.length : objects
  end

  include TreeBuilderArchived
end
