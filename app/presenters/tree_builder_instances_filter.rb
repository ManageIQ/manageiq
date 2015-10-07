class TreeBuilderInstancesFilter < TreeBuilderVmsFilter
  def tree_init_options(_tree_name)
    super.update(:leaf => 'VmCloud')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "instances_filter_treebox",
      :tree_name => "instances_filter_tree",
      :id_prefix => "inf_",
      :autoload  => false
    )
  end
end
