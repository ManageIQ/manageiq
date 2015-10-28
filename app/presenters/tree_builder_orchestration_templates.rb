class TreeBuilderOrchestrationTemplates < TreeBuilder
  private

  def x_get_tree_roots(count_only, _options)
    children = [
      {:id    => 'otcfn',
       :tree  => "otcfn_tree",
       :text  => "CloudFormation Templates",
       :image => "orchestration_template_cfn",
       :tip   => "CloudFormation Templates"},
      {:id    => 'othot',
       :tree  => "othot_tree",
       :text  => "Heat Templates",
       :image => "orchestration_template_hot",
       :tip   => "Heat Templates"},
      {:id    => 'otazu',
       :tree  => "otazu_tree",
       :text  => "Azure Templates",
       :image => "orchestration_template_azure",
       :tip   => "Azure Templates"}
    ]
    count_only ? children.length : children
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

  def x_get_tree_custom_kids(object, count_only, _options)
    classes = {
      "otcfn" => OrchestrationTemplateCfn,
      "othot" => OrchestrationTemplateHot,
      "otazu" => OrchestrationTemplateAzure
    }
    objects = rbac_filtered_objects(classes[object[:id]].all).sort_by { |o| o.name.downcase }
    count_only_or_objects(count_only, objects, nil)
  end
end
