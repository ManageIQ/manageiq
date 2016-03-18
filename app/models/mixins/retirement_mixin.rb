module RetirementMixin
  extend ActiveSupport::Concern

  RETIRED  = 'retired'
  RETIRING = 'retiring'
  ERROR_RETIRING = 'error'

  module ClassMethods
    def retire(ids, options = {})
      ids.each do |id|
        object = find_by_id(id)
        object.retire(options) if object.respond_to?(:retire)
      end
      MiqQueue.put(:class_name => base_model.name, :method_name => "retirement_check")
    end
  end

  def retirement_warn=(days)
    if retirement_warn != days
      self.retirement_last_warn = nil # Reset so that a new warning can be sent out when the time is right
      write_attribute(:retirement_warn, days)
      self.retirement_requester = nil
    end
  end

  def retirement_warned?
    !retirement_last_warn.nil?
  end

  def retirement_warning_due?
    retirement_warn && retires_on && retirement_warn.days.from_now.to_date >= retires_on.to_date
  end

  def retirement_due?
    retires_on && (Date.today >= retires_on_date)
  end

  def retires_on=(timestamp)
    return if retires_on == timestamp

    if timestamp.nil? || (timestamp.to_date > Time.zone.today)
      self.retired = false
      _log.warn("Resetting retirement state from #{retirement_state}") unless retirement_state.nil?
      self.retirement_state = nil
    end
    self.retirement_last_warn = nil # Reset so that a new warning can be sent out when the time is right
    self[:retires_on] = timestamp
    self.retirement_requester = nil
  end

  def retires_on_date
    retires_on.nil? ? nil : retires_on.to_date
  end

  def retire(options = {})
    return unless options.keys.any? { |key| [:date, :warn].include?(key) }

    message = "#{retirement_object_title}: [#{name}]"

    if options.key?(:date)
      date = nil
      date = options[:date].to_date unless options[:date].nil?
      self.retires_on = date

      if date
        message += " is scheduled to retire on date: [#{retires_on_date}]"
      else
        message += " is no longer scheduled to retire"
      end
    end

    if options.key?(:warn)
      message += " and" if options.key?(:date)
      warn = options[:warn]
      self.retirement_warn = warn
      if warn
        message += " has a value for retirement warning days of: [#{retirement_warn}]"
      else
        message += " has no value for retirement warning days"
      end
    end

    save

    raise_retire_audit_event(message)
  end

  def raise_retire_audit_event(message)
    event_name = "#{retirement_event_prefix}_scheduled_to_retire"
    _log.info("#{message}")
    raise_audit_event(event_name, message)
  end

  def retirement_check
    return if self.retired?

    if !retirement_warned? && retirement_warning_due?
      begin
        self.retirement_last_warn = Time.now.utc
        save
        raise_retirement_event(retire_warn_event_name)
      rescue => err
        _log.log_backtrace(err)
      end
    end

    retire_now if retirement_due?
  end

  def retire_now(requester = nil)
    if retired
      return if retired_validated?
      _log.info("#{retirement_object_title}: [#{name}], Retires On Date: [#{retires_on_date}], was previously retired, but currently #{retired_invalid_reason}")
    else
      update_attributes(:retirement_requester => requester)
      event_name = "request_#{retirement_event_prefix}_retire"
      _log.info("calling #{event_name}")
      begin
        raise_retirement_event(event_name, requester)
      rescue => err
        _log.log_backtrace(err)
      end
    end
  end

  def finish_retirement
    raise _("%{name} already retired") % {:name => name} if retired?
    $log.info("Finishing Retirement for [#{name}]")
    update_attributes(:retires_on => Date.today, :retired => true, :retirement_state => "retired")
    message = "#{self.class.base_model.name}: [#{name}], Retires On Date: [#{retires_on}], has been retired"
    $log.info("Calling audit event for: #{message} ")
    raise_audit_event(retired_event_name, message)
    $log.info("Called audit event for: #{message} ")
  end

  def start_retirement
    return if self.retired?
    $log.info("Starting Retirement for [#{name}]")
    update_attributes(:retirement_state => "retiring")
  end

  def retired_validated?
    true
  end

  def retired_invalid_reason
    ""
  end

  def retirement_base_model_name
    @retirement_base_model_name ||= self.class.base_model.name
  end

  def retirement_object_title
    @retirement_object_title ||= retirement_base_model_name
  end

  def retirement_event_prefix
    @retirement_event_prefix ||= retirement_object_title.underscore
  end

  def retire_warn_event_name
    @retire_warn_event_name ||= "#{retirement_event_prefix}_retire_warn".freeze
  end

  def retired_event_name
    @retired_event_name ||= "#{retirement_event_prefix}_retired".freeze
  end

  def raise_retirement_event(event_name, requester = nil)
    $log.info("Raising Retirement Event for [#{name}]")
    MiqEvent.raise_evm_event(self, event_name, setup_event_hash(requester))
  end

  def raise_audit_event(event_name, message)
    event_hash = {
      :target_class => retirement_base_model_name,
      :target_id    => id.to_s,
      :event        => event_name,
      :message      => message
    }
    AuditEvent.success(event_hash)
  end

  def retiring?
    retirement_state == RETIRING
  end

  def error_retiring?
    retirement_state == ERROR_RETIRING
  end

  private

  def setup_event_hash(requester)
    event_hash = {:retirement_initiator => "system"}
    event_hash[retirement_base_model_name.underscore.to_sym] = self
    event_hash[:host] = host if self.respond_to?(:host)
    if requester
      event_hash[:userid] = requester
      event_hash[:retirement_initiator] = "user"
    end
    event_hash[:type] ||= self.class.name
    event_hash
  end
end
