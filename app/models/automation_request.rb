class AutomationRequest < MiqRequest
  alias_attribute :automation_tasks, :miq_request_tasks

  TASK_DESCRIPTION  = 'Automation Request'
  DEFAULT_NAMESPACE = "SYSTEM"
  DEFAULT_CLASS     = "PROCESS"
  DEFAULT_INSTANCE  = "AUTOMATION_REQUEST"
  SOURCE_CLASS_NAME = nil

  ##############################################
  # uri_parts:  instance=IIII|message=MMMM or any subset thereof
  # parameters: var1=vvvvv|var2=wwww|var3=xxxxx
  ##############################################
  def self.create_from_ws(version, user, uri_parts, parameters, requester)
    _log.info("Starting with interface version=<#{version}> for user=<#{user.userid}> with uri_parts=<#{uri_parts.inspect}>, parameters=<#{parameters.inspect}> and requester=<#{requester.inspect}>")

    options = {}
    requester_options = MiqRequestWorkflow.parse_ws_string(requester)
    auto_approve = (requester_options[:auto_approve] == 'true' || requester_options[:auto_approve] == true)

    user = MiqRequestWorkflow.update_requester_from_parameters(requester_options, user)

    uri_options = MiqRequestWorkflow.parse_ws_string(uri_parts)
    [:namespace, :class, :instance, :message].each { |key| options[key] = uri_options.delete(key) if uri_options.key?(key) }
    uri_options.keys.each { |key| _log.warn("invalid keyword <#{key}> specified in uri_parts") }
    options[:namespace]     = (options.delete(:namespace) || DEFAULT_NAMESPACE).strip.gsub(/(^\/|\/$)/, "")  # Strip blanks and slashes from beginning and end of string
    options[:class_name]    = (options.delete(:class) || DEFAULT_CLASS).strip.gsub(/(^\/|\/$)/, "")
    options[:instance_name] = (options.delete(:instance) || DEFAULT_INSTANCE).strip
    options.merge!(parse_schedule_options(parameters.select { |key, _v| key.to_s.include?('schedule') }))

    options[:user_id]  = user.id
    options[:attrs]    = build_attrs(parameters, user)
    options[:miq_zone] = zone(options) if options[:attrs].key?(:miq_zone)

    create_request(options, user, auto_approve)
  end

  def self.create_from_scheduled_task(user, uri_parts, parameters)
    parameters = parameters.stringify_keys
    uri_parts = uri_parts.except(:namespace, :class_name).stringify_keys!
    create_from_ws("1.1", user, uri_parts, parameters, 'auto_approve' => true)
  end

  def self.zone(options)
    zone_name = options[:attrs][:miq_zone]
    return nil if zone_name.blank?
    unless Zone.where(:name => zone_name).exists?
      raise ArgumentError, _("unknown zone %{zone_name}") % {:zone_name => zone_name}
    end
    zone_name
  end

  def requested_task_idx
    [1]
  end

  def customize_request_task_attributes(_req_task_attrs, _idx)
  end

  def my_role(_action = nil)
    'automate'
  end

  def log_request_success(_requester_id, _mode)
    # currently we do not log successful automation requests
  end

  def self.build_attrs(parameters, user)
    parameters = parameters.dup
    object_hash = parameters.select { |key, _v| key.to_s.include?(MiqAeEngine::MiqAeObject::CLASS_SEPARATOR) }
    parameters.extract!(*object_hash.keys)
    MiqRequestWorkflow.parse_ws_string(parameters).merge!(object_hash).tap do |attrs|
      attrs[:userid] = user.userid
    end
  end
  private_class_method :build_attrs

  def self.parse_schedule_options(parameters)
    {:schedule_type => "schedule"}.tap do |hash|
      if parameters['schedule_time']
        hash[:schedule_time] = Time.zone.parse(parameters['schedule_time'])
      else
        hash[:schedule_type] = "immediately"
      end
    end
  end
  private_class_method :parse_schedule_options
end
