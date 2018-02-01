class VmRetireTask < MiqRequestTask
  alias_attribute :vm, :source

  validate :validate_request_type, :validate_state

  AUTOMATE_DRIVES = true

  def self.base_model
    VmRetireTask
  end

  def self.get_description(req_obj)
    name = nil
    if req_obj.source.nil?
      # Single source has not been selected yet
      if req_obj.options[:src_ids].length == 1
        v = Vm.find_by(:id => req_obj.options[:src_ids].first)
        name = v.nil? ? "" : v.name
      else
        name = "Multiple VMs"
      end
    else
      name = req_obj.source.name
    end

    new_settings = []
    "#{request_class::TASK_DESCRIPTION} for: #{name} - #{new_settings.join(", ")}"
  end

  def after_request_task_create
    update_attribute(:description, get_description)
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

  def deliver_to_automate(req_type = request_type, zone = nil)
    task_check_on_delivery

    _log.info("Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")

    if self.class::AUTOMATE_DRIVES
      args = {
        :object_type   => self.class.name,
        :object_id     => id,
        :attrs         => {"request" => req_type},
        :instance_name => "AUTOMATION",
        :user_id       => get_user.id,
        :miq_group_id  => get_user.current_group.id,
        :tenant_id     => get_user.current_tenant.id,
      }

      args[:attrs].merge!(MiqAeEngine.create_automation_attributes(source.class.base_model.name => source))

      zone ||= source.respond_to?(:my_zone) ? source.my_zone : MiqServer.my_zone
      MiqQueue.put(
        :class_name     => 'MiqAeEngine',
        :method_name    => 'deliver',
        :args           => [args],
        :role           => 'automate',
        :zone           => options.fetch(:miq_zone, zone),
        :tracking_label => my_task_id,
      )
      update_and_notify_parent(:state => "pending", :status => "Ok", :message => "Automation Starting")
    else
      execute_queue
    end
  end

  def before_ae_starts(_options)
    reload
    if state.to_s.downcase.in?(%w(pending queued))
      _log.info("Executing #{request_class::TASK_DESCRIPTION} request: [#{description}]")
      update_and_notify_parent(:state => "active", :status => "Ok", :message => "In Process")
    end
  end

  def update_and_notify_parent(*args)
    prev_state = state
    super
    task_finished if state == "finished" && prev_state != "finished"
  end

  def task_finished
  end

  def mark_pending_items_as_finished
    miq_request.miq_request_tasks.each do |s|
      if s.state == 'pending'
        s.update_and_notify_parent(:state => "finished", :status => "Warn", :message => "Error in Request: #{miq_request.id}. Setting pending Task: #{id} to finished.") unless id == s.id
      end
    end
  end
end
