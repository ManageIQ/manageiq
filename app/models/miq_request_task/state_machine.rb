module MiqRequestTask::StateMachine
  delegate :my_role, :to => :miq_request
  delegate :my_zone, :to => :source,      :allow_nil => true
  delegate :my_queue_name, :to => :miq_request

  def tracking_label_id
    "r#{miq_request_id}_#{self.class.base_model.name.underscore}_#{id}"
  end

  def signal_abort
    signal(:abort)
  end

  def signal(phase)
    $log.warn("SIGNAL(#{phase})")
    return signal(:finish) if ![:finish, :provision_error].include?(phase.to_sym) && prematurely_finished?

    self.phase = phase.to_s
    $log.info("Starting Phase <#{self.phase}>")
    save

    begin
      $log.warn("SEND(#{phase})")
      send(phase)
    rescue => err
      case phase
      when :finish
        $log.error("[#{err.class}: #{err.message}] encountered during [#{phase}]")
        $log.log_backtrace(err)
      when :provision_error
        update_and_notify_parent(:state => "finished", :status => "Error", :message => err.message)
        signal(:finish)
      else
        signal(:provision_error)
      end
    end
  end

  def signal_queue(phase)
    method_name, args = phase == :abort ? [:signal_abort, []] : [:signal, [phase]]
    MiqQueue.put(
      :class_name     => self.class.name,
      :instance_id    => id,
      :method_name    => method_name,
      :args           => args,
      :zone           => my_zone,
      :role           => my_role,
      :queue_name     => my_queue_name,
      :tracking_label => tracking_label_id,
    )
  end

  def prematurely_finished?
    if state == 'finished' || status == 'Error'
      _log.warn("Task is prematurely finished in phase:<#{phase}> because state:<#{state}> and status:<#{status}>")
      return true
    end
    false
  end

  def requeue_phase
    mark_execution_servers
    save # Save current phase_context
    MiqQueue.put(
      :class_name     => self.class.name,
      :instance_id    => id,
      :method_name    => phase,
      :deliver_on     => 10.seconds.from_now.utc,
      :zone           => my_zone,
      :role           => my_role,
      :queue_name     => my_queue_name,
      :tracking_label => tracking_label_id,
      :miq_callback => {:class_name => self.class.name, :instance_id => id, :method_name => :execute_callback}
    )
  end
end
