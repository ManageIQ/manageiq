class TreeBuilderImages < TreeBuilder
  has_kids_for ExtManagementSystem, [:x_get_tree_ems_kids]

  include TreeBuilderArchived

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
      :autoload  => true,
      :allow_reselect => TreeBuilder.hide_vms
    )
  end

  def root_options
    [_("Images by Provider"), _("All Images by Provider that I can see")]
  end

  def x_get_tree_roots(count_only, _options)
    count_only_or_objects_filtered(count_only, EmsCloud, "name", :match_via_descendants => TemplateCloud) +
      count_only_or_objects(count_only, x_get_tree_arch_orph_nodes("Images"))
  end

  def x_get_tree_ems_kids(object, count_only)
    count_only_or_objects_filtered(count_only, TreeBuilder.hide_vms ? [] : object.miq_templates, "name")
  end
end
