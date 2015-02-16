class TreeBuilderOrchestrationTemplates < TreeBuilder
  private

  def x_get_tree_roots(options)
    children = [
      {:id    => 'otcfn',
       :tree  => "otcfn_tree",
       :text  => "Cloudformation Templates",
       :image => "orchestration_template_cfn",
       :tip   => "Cloudformation Templates"},
      {:id    => 'othot',
       :tree  => "othot_tree",
       :text  => "Heat Templates",
       :image => "orchestration_template_hot",
       :tip   => "Heat Templates"}
    ]
    options[:count_only] ? children.length : children
  end

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :leaf     => 'OrchestrationTemplate'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'ot_',
      :autoload  => 'true'
    )
  end

  def x_get_tree_custom_kids(object, options)
    classes = {
      "otcfn" => OrchestrationTemplateCfn,
      "othot" => OrchestrationTemplateHot
    }
    objects = rbac_filtered_objects(classes[object[:id]].all).sort_by { |o| o.name.downcase }
    count_only_or_objects(options[:count_only], objects, nil)
  end
end
