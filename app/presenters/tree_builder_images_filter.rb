class TreeBuilderImagesFilter < TreeBuilderVmsFilter
  def tree_init_options(_tree_name)
    super.update(:leaf => 'ManageIQ::Providers::CloudManager::Template')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "images_filter_treebox",
      :tree_name => "images_filter_tree",
      :id_prefix => "imf_",
      :autoload  => false
    )
  end

  def root_options
    [_("All Images"), _("All of the Images that I can see")]
  end
end
