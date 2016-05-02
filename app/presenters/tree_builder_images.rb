class TreeBuilderImages < TreeBuilder
  has_kids_for ExtManagementSystem, [:x_get_tree_ems_kids]

  def tree_init_options(_tree_name)
    {
      :leaf => "ManageIQ::Providers::CloudManager::Template"
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

  def x_get_tree_roots(count_only, _options)
    objects = rbac_filtered_objects(EmsCloud.order("lower(name)"), :match_via_descendants => TemplateCloud)
    objects += [
      {:id => "arch", :text => _("<Archived>"), :image => "currentstate-archived", :tip => _("Archived Images")},
      {:id => "orph", :text => _("<Orphaned>"), :image => "currentstate-orphaned", :tip => _("Orphaned Images")}
    ]
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_ems_kids(object, count_only)
    objects = rbac_filtered_objects(object.miq_templates.order("name"))
    count_only ? objects.length : objects
  end

  include TreeBuilderArchived
end
