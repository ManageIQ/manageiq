class ServiceTemplateTransformationPlanTask < ServiceTemplateProvisionTask
  def self.base_model
    ServiceTemplateTransformationPlanTask
  end

  def after_request_task_create
    update_attributes(:description => "Transforming VM #{source.name}")
  end

  def resource_action
    miq_request.source.resource_actions.detect { |ra| ra.action == 'Provision' }
  end

  def transformation_destination(source_obj)
    miq_request.transformation_mapping.destination(source_obj)
  end

  def update_transformation_progress(progress)
    options[:progress] = (options[:progress] || {}).merge(progress)
    save
  end
end
