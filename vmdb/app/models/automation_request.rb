class AutomationRequest < MiqRequest
  alias_attribute :automation_tasks, :miq_request_tasks

  TASK_DESCRIPTION  = 'Automation Request'
  DEFAULT_NAMESPACE = "SYSTEM"
  DEFAULT_CLASS     = "PROCESS"
  DEFAULT_INSTANCE  = "AUTOMATION_REQUEST"

  ##############################################
  # uri_parts:  instance=IIII|message=MMMM or any subset thereof
  # parameters: var1=vvvvv|var2=wwww|var3=xxxxx
  ##############################################
  def self.create_from_ws(version, userid, uri_parts, parameters, requester)
    _log.info "Starting with interface version=<#{version}> for user=<#{userid}> with uri_parts=<#{uri_parts.inspect}>, parameters=<#{parameters.inspect}> and requester=<#{requester.inspect}>"

    options = {}
    requester_options = MiqRequestWorkflow.parse_ws_string(requester)
    auto_approve = (requester_options[:auto_approve] == 'true' || requester_options[:auto_approve] == true)
    unless requester_options[:user_name].blank?
      userid = requester_options[:user_name]
      _log.warn "Web-service requester changed to <#{userid}>"
    end

    uri_options = MiqRequestWorkflow.parse_ws_string(uri_parts)
    [:namespace, :class, :instance, :message].each { |key| options[key] = uri_options.delete(key) if uri_options.has_key?(key) }
    uri_options.keys.each { |key| _log.warn "invalid keyword <#{key}> specified in uri_parts" }
    options[:namespace]     = (options.delete(:namespace) || DEFAULT_NAMESPACE).strip.gsub(/(^\/|\/$)/, "")  # Strip blanks and slashes from beginning and end of string
    options[:class_name]    = (options.delete(:class)     || DEFAULT_CLASS).strip.gsub(/(^\/|\/$)/, "")
    options[:instance_name] = (options.delete(:instance)  || DEFAULT_INSTANCE).strip

    attrs = MiqRequestWorkflow.parse_ws_string(parameters)
    attrs[:userid] = userid

    user               = User.find_by_userid(userid)
    options[:user_id]  = user.id unless user.nil?
    options[:attrs]    = attrs
    options[:miq_zone] = zone(options) if options[:attrs].key?(:miq_zone)

    self.create_request(options, userid, auto_approve)
  end

  def self.create_request(options, userid, auto_approve=false)
    request = self.create(:options => options, :userid => userid, :request_type => 'automation')
    request.save!  # Force validation errors to raise now

    request.set_description
    request.create_request
    request.call_automate_event_queue("request_created")
    request.approve(userid, "Auto-Approved") if auto_approve == true

    return request.reload # if approved, need to reload
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

  def customize_request_task_attributes(req_task_attrs, idx)
  end

  def my_role
    'automate'
  end

end
