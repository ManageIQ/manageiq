module RetirementMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def retire(ids, options={})
      ids.each do |id|
        object = self.find_by_id(id)
        object.retire(options) if object.respond_to?(:retire)
      end
      MiqQueue.put(:class_name => self.base_model.name, :method_name => "retirement_check")
    end
  end

  def retirement_warn=(seconds)
    if self.retirement_warn != seconds
      self.retirement_last_warn = nil # Reset so that a new warning can be sent out when the time is right
      write_attribute(:retirement_warn, seconds)
    end
  end

  def retirement_warned?
    !self.retirement_last_warn.nil?
  end

  def retirement_warning_due?
    self.retirement_warn && self.retires_on && self.retirement_warn.days.from_now.to_date >= self.retires_on.to_date
  end

  def retirement_due?
    self.retires_on && (Date.today >= self.retires_on_date)
  end

  def retires_on=(timestamp)
    if self.retires_on != timestamp
      self.retired              = false if timestamp.nil? || (timestamp.to_date > Date.today)
      self.retirement_last_warn = nil # Reset so that a new warning can be sent out when the time is right
      write_attribute(:retires_on, timestamp)
    end
  end

  def retires_on_date
    self.retires_on.nil? ? nil : self.retires_on.to_date
  end

  def retire(options={})
    return unless options.keys.any? { |key| [:date, :warn].include?(key) }

    message = "#{retirement_object_title}: [#{self.name}]"

    if options.has_key?(:date)
      date = nil
      date = options[:date].to_date unless options[:date].nil?
      self.retires_on = date

      if date
        message += " is scheduled to retire on date: [#{self.retires_on_date}]"
      else
        message += " is no longer scheduled to retire"
      end
    end

    if options.has_key?(:warn)
      message += " and" if options.has_key?(:date)
      warn = options[:warn]
      self.retirement_warn = warn
      if warn
        message += " has a value for retirement warning days of: [#{self.retirement_warn}]"
      else
        message += " has no value for retirement warning days"
      end
    end

    self.save

    event_name = "#{retirement_event_prefix}_scheduled_to_retire"
    $log.info("MIQ(#{retirement_object_title}#retire) #{message}")
    raise_audit_event(event_name, message)
  end

  def retirement_check
    return if self.retired?

    if !self.retirement_warned? && self.retirement_warning_due?
      begin
        self.retirement_last_warn = Time.now.utc
        self.save
        raise_retirement_event(retire_warn_event_name)
      rescue => err
        $log.log_backtrace(err)
      end
    end

    self.retire_now if self.retirement_due?
  end

  def retiredx=(retired_state)
    case retired_state
    when false
      self.retires_on = nil
      write_attribute(:retired, false)
    when true
      unless self.retired?
        self.retires_on = Date.today
        write_attribute(:retired, true)
      end
    else
    end
  end

  def retire_now
    log_prefix = "MIQ(#{retirement_object_title}#retire_now)"
    unless self.retired
      event_name = "request_#{retirement_event_prefix}_retire"
      $log.info("#{log_prefix} calling #{event_name}")
      begin
        raise_retirement_event(event_name)
      rescue => err
        $log.log_backtrace(err)
      end
    else
      return if retired_validated?
      $log.info("#{log_prefix} #{retirement_object_title}: [#{self.name}], Retires On Date: [#{self.retires_on_date}], was previously retired, but currently #{retired_invalid_reason}")
    end
  end

  def finish_retirement
    unless self.retired?
      $log.info("Finishing Retirement for [#{self.name}]")
      self.retires_on = Date.today
      self.retired    = true
      self.retirement_state = 'retired'
      self.save
      message = "#{self.class.base_model.name}: [#{self.name}], Retires On Date: [#{self.retires_on}], has been retired"
      $log.info("Calling audit event for: #{message} ")
      raise_audit_event(retired_event_name, message)
      $log.info("Called audit event for: #{message} ")
    end
  end

  def start_retirement
    unless self.retired?
      $log.info("Starting Retirement for [#{self.name}]")
      self.retirement_state = 'retiring'
      self.save
    end
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

  def raise_retirement_event(event_name)
    event_hash = {}
    event_hash[retirement_base_model_name.underscore.to_sym] = self
    event_hash[:host] = self.host if self.respond_to?(:host)
    MiqEvent.raise_evm_event(self, event_name, event_hash)
  end

  def raise_audit_event(event_name, message)
    event_hash = {
      :target_class => retirement_base_model_name,
      :target_id    => self.id.to_s,
      :event        => event_name,
      :message      => message
    }
    AuditEvent.success(event_hash)
  end

  def is_or_being_retired?
    self.retired || !self.retirement_state.blank?
  end

  def unretire
    self.update_attributes(:retired => false, :retirement_state => nil)
  end

end
