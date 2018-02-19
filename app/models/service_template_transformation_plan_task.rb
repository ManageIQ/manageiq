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

  def task_finished
    # update the status of vm transformation status in the plan
    vm_request.update_attributes(:status => status == 'Ok' ? 'Completed' : 'Failed')
  end

  def task_active
    vm_request.update_attributes(:status => 'Active')
  end

  private

  def vm_request
    miq_request.vm_requests.find_by(:resource => source)
  end
end
