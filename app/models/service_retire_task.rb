class ServiceRetireTask < MiqRetireTask
  def self.base_model
    ServiceRetireTask
  end

  def self.model_being_retired
    Service
  end

  def update_and_notify_parent(*args)
    prev_state = state
    super
    task_finished if state == "finished" && prev_state != "finished"
  end

  def task_finished
    update_attributes(:status => status == 'Ok' ? 'Completed' : 'Failed')
  end

  def task_active
    update_attributes(:status => 'Active')
  end

  def after_request_task_create
    update_attributes(:description => get_description)
    parent_svc = Service.find_by(:id => options[:src_ids])
    _log.info("- creating service tasks for service <#{self.class.name}:#{id}>")

    create_retire_subtasks(parent_svc)
  end

  def create_retire_subtasks(parent_service)
    parent_service.direct_service_children.each { |child| create_retire_subtasks(child) }
    parent_service.service_resources.collect do |svc_rsc|
      next unless retireable?(svc_rsc, parent_service)
      nh = attributes.except("id", "created_on", "updated_on", "type", "state", "status", "message")
      nh['options'] = options.except(:child_tasks)
      # Initial Options[:dialog] to an empty hash so we do not pass down dialog values to child services tasks
      nh['options'][:dialog] = {}
      new_task = create_task(svc_rsc, parent_service, nh)
      new_task.after_request_task_create
      miq_request.miq_request_tasks << new_task
      new_task.deliver_to_automate
      new_task
    end.compact!
  end

  def retireable?(svc_rsc, parent_service)
    srr = svc_rsc.resource
    srr.present? &&
      srr.respond_to?(:retire_now) &&
      srr.type.present? &&
      (svc_rsc.resource_type != "ServiceTemplate" || self.class.include_service_template?(self, srr.id, parent_service))
  end

  def create_task(svc_rsc, parent_service, nh)
    new_task = (svc_rsc.resource.type.demodulize + "RetireTask").constantize.new(nh)
    new_task.options.merge!(
      :src_id              => svc_rsc.resource.id,
      :service_resource_id => svc_rsc.id,
      :parent_service_id   => parent_service.id,
      :parent_task_id      => id,
    )
    new_task.source = svc_rsc.resource
    new_task.request_type = svc_rsc.resource.type.demodulize.downcase + "_retire"
    new_task.save!
    new_task
  end
end
