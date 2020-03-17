class ServiceTemplateTransformationPlanRequest < ServiceTemplateProvisionRequest
  TASK_DESCRIPTION = 'VM Transformations'.freeze
  SERVICE_ORDER_CLASS = '::ServiceOrderV2V'.freeze

  delegate :transformation_mapping, :vm_resources, :to => :source

  def requested_task_idx
    vm_resources.where(:status => ServiceResource::STATUS_APPROVED)
  end

  def customize_request_task_attributes(req_task_attrs, vm_resource)
    req_task_attrs[:source] = vm_resource.resource
  end

  def source_vms
    vm_resources.where(:status => [ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_FAILED]).pluck(:resource_id)
  end

  def validate_conversion_hosts
    transformation_mapping.transformation_mapping_items.select do |item|
      %w(EmsCluster CloudTenant).include?(item.source_type)
    end.all? do |item|
      item.destination.ext_management_system.conversion_hosts.present?
    end
  end

  def validate_vm(_vm_id)
    # TODO: enhance the logic to determine whether this VM can be included in this request
    true
  end

  def approve_vm(vm_id)
    vm_resources.find_by(:resource_id => vm_id).update!(:status => ServiceResource::STATUS_APPROVED)
  end

  def cancel
    update(:cancelation_status => MiqRequest::CANCEL_STATUS_REQUESTED)
    miq_request_tasks.each(&:cancel)
  end

  def update_request_status
    super
    if request_state == 'finished' && status == 'Ok'
      Notification.create(:type => "transformation_plan_request_succeeded", :options => {:plan_name => description})
    elsif request_state == 'finished' && status != 'Ok'
      Notification.create(:type => "transformation_plan_request_failed", :options => {:plan_name => description}, :subject => self)
    end
  end

  def post_create_request_tasks
    miq_request_tasks.each do |req_task|
      job_options = {
        :target_class => req_task.class.name,
        :target_id    => req_task.id
      }
      job = InfraConversionJob.create_job(job_options)
      req_task.options[:infra_conversion_job_id] = job.id
      req_task.save!
    end
  end
end
