class MiqRetireTask < MiqRequestTask
  validate :validate_request_type, :validate_state

  AUTOMATE_DRIVES = true

  def self.get_description(req_obj)
    name = if req_obj.source.nil?
             m = model_being_retired.find_by(:id => req_obj.options[:src_ids].first)
             m.nil? ? "" : m.name
           else
             req_obj.source.name
           end

    new_settings = []
    "#{request_class::TASK_DESCRIPTION} for: #{name}"
  end

  def deliver_to_automate(req_type = request_type, zone = nil)
    task_check_on_delivery

    _log.info("Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")
    if self.class::AUTOMATE_DRIVES
      args = {
        :object_type   => self.class.name,
        :object_id     => id,
        :attrs         => {"request" => req_type},
        :instance_name => "AUTOMATION",
        :user_id       => miq_request.requester.id,
        :miq_group_id  => miq_request.requester.current_group_id,
        :tenant_id     => miq_request.requester.current_group.tenant_id,
      }

      MiqAeEngine::set_automation_attributes_from_objects(source, args[:attrs])

      zone ||= source.respond_to?(:my_zone) ? source.my_zone : MiqServer.my_zone
      MiqQueue.put(
        :class_name     => 'MiqAeEngine',
        :method_name    => 'deliver',
        :args           => [args],
        :role           => 'automate',
        :zone           => options.fetch(:miq_zone, zone),
        :tracking_label => tracking_label_id,
      )
      update_and_notify_parent(:state => "pending", :status => "Ok", :message => "Automation Starting")
    else
      execute_queue
    end
  end

  def after_request_task_create
    update(:description => get_description)
  end

  def after_ae_delivery(ae_result)
    _log.info("ae_result=#{ae_result.inspect}")
    reload

    return if ae_result == 'retry'
    return if miq_request.state == 'finished'

    if ae_result == 'ok'
      update_and_notify_parent(:state => "finished", :status => "Ok", :message => display_message("#{request_class::TASK_DESCRIPTION} completed"))
    else
      mark_pending_items_as_finished
      update_and_notify_parent(:state => "finished", :status => "Error", :message => display_message("#{request_class::TASK_DESCRIPTION} failed"))
    end
  end

  def before_ae_starts(_options)
    reload
    if state.to_s.downcase.in?(%w(pending queued))
      _log.info("Executing #{request_class::TASK_DESCRIPTION} request: [#{description}]")
      update_and_notify_parent(:state => "active", :status => "Ok", :message => "In Process")
    end
  end

  def mark_pending_items_as_finished
    miq_request.miq_request_tasks.each do |s|
      if s.state == 'pending'
        s.update_and_notify_parent(:state => "finished", :status => "Warn", :message => "Error in Request: #{miq_request.id}. Setting pending Task: #{id} to finished.") unless id == s.id
      end
    end
  end

  def completed_state
    "retired"
  end

  def self.display_name(number = 1)
    n_('Retire Task', 'Retire Tasks', number)
  end
end
