class TreeBuilderInstancesFilter < TreeBuilderVmsFilter
  def tree_init_options(tree_name)
    super.update(:leaf => 'VmCloud')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id => "instances_filter_treebox",
      :tree_name => "instances_filter_tree",
      :id_prefix => "inf_",
      #:json_tree => @temp[:instances_filter_tree], # @tree_nodes
      #:onclick => "cfmeOnClick_SelectTreeNode",
      :select_node => "#{x_node(:instances_filter_tree)}",
      #:base_id => "root",
      #:no_base_exp => true,
      #:exp_tree => false,
      #:highlighting => true,
      #:tree_state => true,
      :autoload => false
    )
  end
end
