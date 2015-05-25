class TreeBuilderTemplateFilter < TreeBuilderVmsFilter
  def tree_init_options(tree_name)
    super.update(:leaf => 'MiqTemplate')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id     => "templates_filter_treebox",
      :tree_name   => "templates_filter_tree",
      :id_prefix   => "tf_",
      :autoload    => false
    )
  end
end
