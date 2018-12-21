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
    update_attributes(:status => status == 'Ok' ? 'Completed' : 'Failed')
  end

  def task_active
    update_attributes(:status => 'Active')
  end

  def after_request_task_create
    update_attributes(:description => get_description)
    parent_svc = Service.find_by(:id => options[:src_ids])
    _log.info("- creating service tasks for service <#{self.class.name}:#{id}>")
    create_retire_subtasks(parent_svc, self)
  end

  def create_retire_subtasks(parent_service, parent_task)
    parent_service.service_resources.collect do |svc_rsc|
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
      create_retire_subtasks(svc_rsc.resource, new_task) if svc_rsc.resource.kind_of?(Service)
      new_task.after_request_task_create
      miq_request.miq_request_tasks << new_task
      new_task.tap(&:deliver_to_automate)
    end.compact!
  end

  def create_task(svc_rsc, parent_service, nh, parent_task)
    (svc_rsc.resource.type.demodulize + "RetireTask").constantize.new(nh).tap do |task|
      task.options.merge!(
        :src_id              => svc_rsc.resource.id,
        :service_resource_id => svc_rsc.id,
        :parent_service_id   => parent_service.id,
        :parent_task_id      => parent_task.id,
      )
      task.request_type = svc_rsc.resource.type.demodulize.underscore.downcase + "_retire"
      task.source = svc_rsc.resource
      parent_task.miq_request_tasks << task
      task.save!
    end
  end
end
