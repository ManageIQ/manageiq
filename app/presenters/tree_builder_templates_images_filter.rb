class TreeBuilderTemplatesImagesFilter < TreeBuilderVmsFilter
  def tree_init_options(_tree_name)
    super.update(:leaf => 'MiqTemplate')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "templates_images_filter_treebox",
      :tree_name => "templates_images_filter_tree",
      :id_prefix => "tf_",
    )
  end
end
