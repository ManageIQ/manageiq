class EmsEventHelper

  def initialize(event)
    raise ArgumentError, "event must be an EmsEvent" unless event.kind_of?(EmsEvent)
    @event = event
  end

  def handle
    before_handle

    handle_event
    handle_alert_event
    handle_alarm_event
    handle_automation_event

    after_handle
  end

  def before_handle
    $log.info "MIQ(EmsEventHandler-handle_event) Processing EMS event [#{@event.event_type}] chain_id [#{@event.chain_id}] on EMS [#{@event.ems_id}]..."
  end

  def after_handle
    $log.info "MIQ(EmsEventHandler-handle_event) Processing EMS event [#{@event.event_type}] chain_id [#{@event.chain_id}] on EMS [#{@event.ems_id}]...Complete"
  end

  def handle_event()
    begin
      routine = VMDB::Config.new('event_handling').config[:event_handling][@event.event_type.to_sym]
    rescue => err
      $log.log_backtrace(err)
      return
    end

    handle_routine(routine)
  end

  def handle_routine(routine)
    return unless routine.kind_of?(Array)
    $log.debug "MIQ(EmsEventHandler-handle_routine) Handling event [#{@event.event_type}] with the following routine: #{routine.inspect}"
    routine.each { |step| handle_step(step) }
  end

  def handle_step(step)
    return unless step.kind_of?(Hash) && step.length == 1

    step_type = step.keys[0]
    targets = step[step_type]
    return unless targets.kind_of?(Array)

    $log.debug "MIQ(EmsEventHandler-handle_step) Performing routine step [#{step_type}] with the following targets: #{targets.inspect}"

    case step_type.to_s
    when 'refresh'
      refresh_targets = targets.collect { |t| @event.get_target("#{t}_refresh_target") }.compact.uniq
      return if refresh_targets.empty?

      $log.debug "MIQ(EmsEventHandler-handle_step) Refreshing: #{refresh_targets.collect { |w| [w.class, w.id] }.inspect}"
      EmsRefresh.queue_refresh(refresh_targets)

    when 'scan'
      missing_targets = []
      targets.each do |t|
        target = @event.get_target(t)
        if target.nil?
          # Queue that target for refresh instead
          $log.debug "MIQ(EmsEventHandler-handle_step) Unable to find target [#{t}].  Queueing for refresh."
          missing_targets << t
        else
          $log.debug "MIQ(EmsEventHandler-handle_step) Scanning [#{t}] [#{target.id}] name: [#{target.name}]"
          target.scan
        end
      end

      unless missing_targets.empty?
        $log.debug "MIQ(EmsEventHandler-handle_step) Performing refresh on the following targets that were not found #{missing_targets.inspect}."
        handle_step({:refresh => missing_targets})
      end

    when 'call'
      return unless targets.length >= 2

      target = @event.get_target(targets[0])
      if target.nil?
        # Kick off the appropriate refresh
        $log.debug "MIQ(EmsEventHandler-handle_step) Unable to find target [#{targets[0]}].  Performing refresh."
        handle_step({:refresh => [targets[0]]})
      else
        methods = targets[1]
        params = targets[2..-1]

        $log.debug "MIQ(EmsEventHandler-handle_step) Calling method [#{target.class}, #{target.id}].#{methods}(#{params.inspect[1..-2]})"

        methods = methods.split('.').collect { |m| [m] }
        methods[-1] += params if params.length > 0

        methods.each { |m| target = target.send(*m) }
      end

    when 'policy'
      return unless targets.length >= 1

      target = @event.get_target(targets[0])
      return if target.nil? || @event.ems_id.nil?

      policy_event = targets[1] || @event.event_type
      return if policy_event.nil?

      if targets[2].nil?
        policy_src = @event.ext_management_system
      else
        begin
          policy_src = target.send(targets[2])
        rescue => err
          $log.warn "MIQ(EmsEventHandler-handle_step) Error: #{err.message}, getting policy source, skipping policy evaluation"
          policy_src = nil
        end
      end
      return if policy_src.nil?
      inputs = {target.class.name.downcase.singularize.to_sym => target, policy_src.class.table_name.to_sym => policy_src, :ems_event => @event}
      begin
        MiqEvent.raise_evm_event(target, policy_event, inputs)
      rescue => err
        $log.log_backtrace(err)
      end
    end
  end

  def handle_automation_event
    return unless MiqServer.my_server.has_role?(:automate)

    begin
      MiqAeEvent.raise_ems_event(@event)
    rescue => err
      $log.log_backtrace(err)
    end
  end

  def handle_alert_event
    handle_step("policy" => ["src_vm", @event.event_type]) if MiqAlert.event_alertable?(@event.event_type)
  end

  def handle_alarm_event
    # TODO:
    # => Figure out the target - ems, custer, host, vm for event
    # => Get alarm MOR and EMS
    # => Find alerts that match EMS and alarm MOR - Not sure if this should be done here or in alert model from queue
    return unless @event.event_type == "AlarmStatusChangedEvent"
    return unless @event.full_data && @event.full_data["to"] = "red"

    $log.info("MIQ(EmsEventHandler-handle_alarm_event) event: [#{@event.attributes.inspect}]")
    $log.info("MIQ(EmsEventHandler-handle_alarm_event) event.full_data: [#{@event.full_data.inspect}]")
    ems_id = @event.ems_id
    target = nil
    [:vm, :host].each do |name|
      target = @event.send(name)
      break if target
    end
    alarm_mor = @event.full_data.fetch_path("alarm", "alarm") unless @event.full_data.nil?

    if alarm_mor.nil? || target.nil? || ems_id.nil?
      $log.warn "MIQ(EmsEventHandler-handle_alarm_event) Alarm Event missing data required for evaluating Alerts, skipping. Full data: [#{@event.full_data.inspect}]"
      return
    end
    alarm_event = "#{@event.event_type}_#{ems_id}_#{alarm_mor}"
    MiqEvent.raise_evm_alert_event_queue(target, alarm_event)
  end
end
