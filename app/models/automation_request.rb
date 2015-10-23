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
    _log.info "Starting with interface version=<#{version}> for user=<#{user.userid}> with uri_parts=<#{uri_parts.inspect}>, parameters=<#{parameters.inspect}> and requester=<#{requester.inspect}>"

    options = {}
    requester_options = MiqRequestWorkflow.parse_ws_string(requester)
    auto_approve = (requester_options[:auto_approve] == 'true' || requester_options[:auto_approve] == true)
    unless requester_options[:user_name].blank?
      user = User.find_by_userid!(requester_options[:user_name])
      _log.warn "Web-service requester changed to <#{user.userid}>"
    end

    uri_options = MiqRequestWorkflow.parse_ws_string(uri_parts)
    [:namespace, :class, :instance, :message].each { |key| options[key] = uri_options.delete(key) if uri_options.key?(key) }
    uri_options.keys.each { |key| _log.warn "invalid keyword <#{key}> specified in uri_parts" }
    options[:namespace]     = (options.delete(:namespace) || DEFAULT_NAMESPACE).strip.gsub(/(^\/|\/$)/, "")  # Strip blanks and slashes from beginning and end of string
    options[:class_name]    = (options.delete(:class) || DEFAULT_CLASS).strip.gsub(/(^\/|\/$)/, "")
    options[:instance_name] = (options.delete(:instance) || DEFAULT_INSTANCE).strip

    attrs = MiqRequestWorkflow.parse_ws_string(parameters)

    attrs[:userid]     = user.userid
    options[:user_id]  = user.id
    options[:attrs]    = attrs
    options[:miq_zone] = zone(options) if options[:attrs].key?(:miq_zone)

    create_request(options, user, auto_approve)
  end

  def self.zone(options)
    zone_name = options[:attrs][:miq_zone]
    return nil if zone_name.blank?
    raise ArgumentError, "unknown zone #{zone_name}" unless Zone.where(:name => zone_name).exists?
    zone_name
  end

  def requested_task_idx
    [1]
  end

  def customize_request_task_attributes(_req_task_attrs, _idx)
  end

  def my_role
    'automate'
  end

  def log_request_success(_requester_id, _mode)
    # currently we do not log successful automation requests
  end
end
