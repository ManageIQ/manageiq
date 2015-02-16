class TreeBuilderTemplateFilter < TreeBuilderVmsFilter
  def tree_init_options(tree_name)
    super.update(:leaf => 'MiqTemplate')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id => "templates_filter_treebox",
      :tree_name => "templates_filter_tree",
      :id_prefix => "tf_",
      #:json_tree => @temp[:templates_filter_tree], # @tree_nodes
      #:onclick => "cfmeOnClick_SelectTreeNode",
      :select_node=>"#{x_node(:templates_filter_tree)}",
      #:base_id => "root",
      #:no_base_exp => true,
      #:exp_tree => false,
      #:highlighting => true,
      #:tree_state => true,
      :autoload => false
    )
  end
end
