module RetirementMixin
  extend ActiveSupport::Concern
  RETIREMENT_ERROR = 'error'.freeze
  RETIREMENT_INITIALIZING = 'initializing'.freeze
  RETIREMENT_RETIRED  = 'retired'.freeze
  RETIREMENT_RETIRING = 'retiring'.freeze

  included do
    scope :scheduled_to_retire, -> { where(arel_table[:retires_on].not_eq(nil).or(arel_table[:retired].not_eq(true))) }
  end

  module ClassMethods
    def make_retire_request(*src_ids, requester)
      klass = (name.demodulize + "RetireRequest").constantize
      options = {:src_ids => src_ids.presence, :__request_type__ => klass.request_types.first}
      set_retirement_requester(options[:src_ids], requester)
      klass.make_request(nil, options, requester, true)
    end

    def retire(ids, options = {})
      ids.each do |id|
        object = find_by(:id => id)
        object.retire(options) if object.respond_to?(:retire)
      end
      q_options = {:class_name => 'RetirementManager', :method_name => 'check'}
      user = User.current_user
      q_options.merge!(:user_id => user.id, :group_id => user.current_group.id, :tenant_id => user.current_tenant.id) if user
      MiqQueue.put(q_options)
    end

    def set_retirement_requester(obj_ids, requester)
      existing_objects = where(:id => obj_ids)
      updated_count = existing_objects.update_all(:retirement_requester => requester.userid)
      if updated_count != obj_ids.count
        _log.info("Retirement requester for #{self.name} #{(obj_ids - existing_objects.pluck(:id))} not set because objects not found")
      else
        _log.info("Retirement requester for #{self.name} #{obj_ids} being set to #{requester.userid}")
      end
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
    retirement_warn && retires_on && retirement_warn.days.from_now >= retires_on
  end

  def retirement_due?
    retires_on && (Time.zone.now >= retires_on)
  end

  def retires_on=(timestamp)
    return if retires_on == timestamp

    if timestamp.nil? || (timestamp > Time.zone.now)
      self.retired = false
      _log.warn("Resetting retirement state from #{retirement_state}") unless retirement_state.nil?
      self.retirement_state = nil
    end

    self.retirement_last_warn = nil # Reset so that a new warning can be sent out when the time is right
    self[:retires_on] = timestamp
    self.retirement_requester = nil
  end

  def extend_retires_on(days, date = Time.zone.now)
    raise _("Invalid Date specified: %{date}") % {:date => date} unless date.kind_of?(ActiveSupport::TimeWithZone)
    _log.info("Extending Retirement Date on #{self.class.name} id:<#{self.id}>, name:<#{self.name}> ")
    new_retires_date = date.in_time_zone + days.to_i.days
    _log.info("Original Date: #{date} Extend days: #{days} New Retirement Date: #{new_retires_date}")
    self.retires_on = new_retires_date
    save
  end

  def retire(options = {})
    return unless options.keys.any? { |key| [:date, :warn].include?(key) }

    message = "#{retirement_object_title}: [#{name}]"

    if options.key?(:date)
      date = nil
      date = options[:date].in_time_zone unless options[:date].nil?
      self.retires_on = date

      if date
        message += " is scheduled to retire on: [#{retires_on.strftime("%x %R %Z")}]"
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
    _log.info(message.to_s)
    raise_audit_event(event_name, message)
  end

  def retirement_check
    return if retired? || retiring? || retirement_initialized?
    requester = system_context_requester

    if !retirement_warned? && retirement_warning_due?
      begin
        self.retirement_last_warn = Time.now.utc
        save
        raise_retirement_event(retire_warn_event_name, requester)
      rescue => err
        _log.log_backtrace(err)
      end
    end

    self.class.make_retire_request(id, requester) if retirement_due?
  end

  def retire_now(requester = nil)
    if retired
      return if retired_validated?
      _log.info("#{retirement_object_title}: [#{name}], Retires On: [#{retires_on.strftime("%x %R %Z")}], was previously retired, but currently #{retired_invalid_reason}")
    elsif retiring?
      _log.info("#{retirement_object_title}: [#{name}] retirement in progress")
    else
      lock do
        reload
        if error_retiring? || retirement_state.blank?
          update_attributes(:retirement_state => "initializing", :retirement_requester => requester)
          event_name = "request_#{retirement_event_prefix}_retire"
          _log.info("calling #{event_name}")
          begin
            raise_retirement_event(event_name, requester ||= current_user)
          rescue => err
            _log.log_backtrace(err)
          end
        else
          _log.info("#{retirement_object_title}: retirement for [#{name}] got updated while waiting to be unlocked and is now #{retirement_state}")
        end
      end
    end
  end

  def finish_retirement
    raise _("%{name} already retired") % {:name => name} if retired?
    $log.info("Finishing Retirement for [#{name}]")
    requester = retirement_requester
    update_attributes(:retires_on => Time.zone.now, :retired => true, :retirement_state => "retired")
    message = "#{self.class.base_model.name}: [#{name}], Retires On: [#{retires_on.strftime("%x %R %Z")}], has been retired"
    $log.info("Calling audit event for: #{message} ")
    raise_audit_event(retired_event_name, message, requester)
    $log.info("Called audit event for: #{message} ")
  end

  def start_retirement
    return if retired? || retiring?
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

  def retirement_initialized?
    retirement_state == RETIREMENT_INITIALIZING
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
    q_options = q_user_info(retire_queue_options, requester)
    $log.info("Raising Retirement Event for [#{name}] with queue options: #{q_options.inspect}")
    MiqEvent.raise_evm_event(self, event_name, setup_event_hash(requester), q_options)
  end

  def raise_audit_event(event_name, message, requester = nil)
    event_hash = {
      :target_class => retirement_base_model_name,
      :target_id    => id.to_s,
      :event        => event_name,
      :message      => message
    }
    event_hash[:userid] = requester if requester.present?
    AuditEvent.success(event_hash)
  end

  def retiring?
    retirement_state == RETIREMENT_RETIRING
  end

  def error_retiring?
    retirement_state == RETIREMENT_ERROR
  end

  private

  def retire_queue_options
    valid_zone? ? {:zone => my_zone} : {}
  end

  def valid_zone?
    respond_to?(:my_zone) && my_zone.present?
  end

  def system_context_requester
    if try(:evm_owner_id).present?
      User.find(evm_owner_id)
    else
      $log.info("System context defaulting to admin user because owner of #{name} not set.")
      User.super_admin
    end
  end

  def current_user
    User.find_by(:userid => User.current_user.try(:userid))
  end

  def q_user_info(q_options, requester)
    if requester.present?
      if requester.kind_of?(String)
        requester = User.find_by(:userid => requester)
      end
      q_options[:user_id] = requester.id
      if requester.current_group.present? && requester.current_tenant.present?
        q_options[:group_id] = requester.current_group.id
        q_options[:tenant_id] = requester.current_tenant.id
      end
    end
    q_options
  end

  def setup_event_hash(requester)
    {}.tap do |event|
      event[:userid] = requester
      event[retirement_base_model_name.underscore.to_sym] = self
      event[:host] = host if respond_to?(:host)
      event[:type] ||= self.class.name
    end
  end
end
