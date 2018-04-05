class ServiceTemplateTransformationPlanTask < ServiceTemplateProvisionTask
  def self.base_model
    ServiceTemplateTransformationPlanTask
  end

  def self.get_description(req_obj)
    source_name = req_obj.source.name
    req_obj.kind_of?(ServiceTemplateTransformationPlanRequest) ? source_name : "Transforming VM [#{source_name}]"
  end

  def after_request_task_create
    update_attributes(:description => get_description)
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
    vm_resource.update_attributes(:status => status == 'Ok' ? ServiceResource::STATUS_COMPLETED : ServiceResource::STATUS_FAILED)
  end

  def task_active
    vm_resource.update_attributes(:status => ServiceResource::STATUS_ACTIVE)
  end

  private

  def vm_resource
    miq_request.vm_resources.find_by(:resource => source)
  end
end
