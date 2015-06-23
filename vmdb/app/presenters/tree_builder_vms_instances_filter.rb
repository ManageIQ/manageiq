class TreeBuilderVmsInstancesFilter < TreeBuilderVmsFilter
  def tree_init_options(_tree_name)
    super.update(:leaf => 'Vm')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "vms_instances_filter_treebox",
      :tree_name => "vms_instances_filter_tree",
      :id_prefix => "vf_",
    )
  end
end
