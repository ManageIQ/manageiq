class ServiceRetireTask < MiqRetireTask
  default_value_for :request_type, "service_retire"

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
    if status != 'Ok'
      update(:status => 'Error')
    end
  end

  def task_active
    update(:status => 'Active')
  end

  def after_request_task_create
    update(:description => get_description)
    Service.where(:id => options[:src_ids]).each do |parent_svc|
      if create_subtasks?(parent_svc)
        _log.info("- creating service subtasks for service task <#{self.class.name}:#{id}>, service <#{parent_svc.id}>")
        create_retire_subtasks(parent_svc, self)
      end
    end
  end

  def create_retire_subtasks(parent_service, parent_task)
    parent_service.service_resources.collect do |svc_rsc|
      next if svc_rsc.resource.respond_to?(:retired?) && svc_rsc.resource.retired?
      next unless svc_rsc.resource.try(:retireable?)
      # TODO: the next line deals with the filtering for provisioning
      # (https://github.com/ManageIQ/manageiq/blob/3921e87915b5a69937b9d4a70bb24ab71b97c165/app/models/service_template/filter.rb#L5)
      # which should be extended to retirement as part of later work
      # svc_rsc.resource_type != "ServiceTemplate" || self.class.include_service_template?(self, srr.id, parent_service)
      nh = attributes.except("id", "created_on", "updated_on", "type", "state", "status", "message")
      nh['options'] = options.except(:child_tasks)
      # Initial Options[:dialog] to an empty hash so we do not pass down dialog values to child services tasks
      nh['options'][:dialog] = {}
      new_task = create_task(svc_rsc, parent_service, nh, parent_task)
      new_task.after_request_task_create
      miq_request.miq_request_tasks << new_task
      new_task.tap(&:deliver_to_automate)
    end.compact!
  end

  def create_task(svc_rsc, parent_service, nh, parent_task)
    task_type = retire_task_type(svc_rsc.resource.class)
    task_type.new(nh).tap do |task|
      task.options.merge!(
        :src_ids             => [svc_rsc.resource.id],
        :service_resource_id => svc_rsc.id,
        :parent_service_id   => parent_service.id,
        :parent_task_id      => parent_task.id,
      )
      task.request_type = task_type.name.underscore[0..-6]
      task.source = svc_rsc.resource
      parent_task.miq_request_tasks << task
      task.save!
    end
  end

  private

  def create_subtasks?(parent_svc)
    !parent_svc.try(:retain_resources_on_retirement?)
  end

  def retire_task_type(resource_type)
    (resource_type.base_class.name + "RetireTask").safe_constantize || (resource_type.name.demodulize + "RetireTask").safe_constantize
  end
end
