class TreeBuilderImagesFilter < TreeBuilderVmsFilter
  def tree_init_options(tree_name)
    super.update(:leaf => 'TemplateCloud')
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id => "images_filter_treebox",
      :tree_name => "images_filter_tree",
      :id_prefix => "imf_",
      #:json_tree => @temp[:images_filter_tree], # @tree_nodes
      #:onclick => "cfmeOnClick_SelectTreeNode",
      :select_node => "#{x_node(:images_filter_tree)}",
      #:base_id => "root",
      #:no_base_exp => true,
      #:exp_tree => false,
      #:highlighting => true,
      #:tree_state => true,
      :autoload => false
    )
  end
end
