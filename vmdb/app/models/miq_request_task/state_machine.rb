module MiqRequestTask::StateMachine
  def my_task_id
    "#{self.class.base_model.name.underscore}_#{self.id}"
  end

  def my_role
    self.miq_request.my_role
  end

  def my_zone
    source.try(:my_zone)
  end

  def respond_to_signal?(phase)
    respond_to?(phase)
  end

  def signal(phase)
    return signal(:finish) if ![:finish, :provision_error].include?(phase.to_sym) && prematurely_finished?

    self.phase = phase.to_s
    $log.info "Starting Phase <#{self.phase}>"
    self.save

    begin
      self.send(phase)
    rescue => err
      if [:finish, :provision_error].include?(phase.to_sym)
        $log.error("MIQ(#{self.class.name}#signal) [#{err.message}] encountered during [#{phase}]")
        $log.log_backtrace(err)
      else
        self.phase_context.delete(:error_message)

        # HACK: Psych is unable to deserialize an Exception that contains a
        #   NameError::message as its message.  When deserialized, it will raise
        #   "TypeError: allocator undefined for NameError::message".  Calling
        #   .message will dereference it and turn it into a String which is
        #   serializable.  For more information about NameError::message, see
        #   http://www.carboni.ca/blog/p/Ruby-Did-You-Know-That-5-NameErrormessage
        #
        #   In addition, backtrace information is not available, because it is
        #   not an instance variable, but is instead dynamically generated.
        #
        #   As such, we store the exception's components separately in the
        #   phase context.
        self.phase_context[:exception_class]     = err.class.name
        self.phase_context[:exception_message]   = err.message
        self.phase_context[:exception_backtrace] = err.backtrace
        self.phase_context[:error_phase] = phase
        signal :provision_error
      end
    end
  end

  def signal_queue(phase)
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'signal',
      :args        => [phase],
      :zone        => my_zone,
      :role        => my_role,
      :task_id     => my_task_id,
    )
  end

  def prematurely_finished?
    if self.state == 'finished' || self.status == 'Error'
      $log.warn("MIQ(#{self.class.name}#prematurely_finished) Task is prematurely finished in phase:<#{self.phase}> because state:<#{self.state}> and status:<#{self.status}>")
      return true
    end
    return false
  end

  def requeue_phase
    self.save # Save current phase_context
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => self.id,
      :method_name  => self.phase,
      :deliver_on   => 10.seconds.from_now.utc,
      :zone         => my_zone,
      :role         => my_role,
      :task_id      => my_task_id,
      :miq_callback => {:class_name => self.class.name, :instance_id => self.id, :method_name => :execute_callback}
    )
  end

  def provision_error
    exception_class     = self.phase_context.delete(:exception_class).try(:constantize)
    exception_message   = self.phase_context.delete(:exception_message)
    exception_backtrace = self.phase_context.delete(:exception_backtrace)

    error_phase         = self.phase_context.delete(:error_phase)
    error_message       = self.phase_context.delete(:error_message) || "[#{exception_class}]: #{exception_message}"

    $log.error("MIQ(#{self.class.name}#provision_error) [#{error_message}] encountered during phase [#{error_phase}]")
    $log.error(exception_backtrace.join("\n")) if exception_backtrace && exception_class && !(exception_class <= MiqException::MiqProvisionError)

    update_and_notify_parent(:state => "finished", :status => "Error", :message => error_message)
    signal :finish
  end
end
