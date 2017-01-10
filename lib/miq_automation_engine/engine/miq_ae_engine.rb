require 'uri'

Dir.glob(Pathname.new(__dir__).join("miq_ae_engine/*.rb")) do |file|
  require_relative "miq_ae_engine/#{File.basename(file)}"
end

module MiqAeEngine
  DEFAULT_ATTRIBUTES = %w( User::user MiqServer::miq_server object_name )
  AE_ROOT_DIR            = File.expand_path(File.join(Rails.root,    'product/automate'))
  AE_IMPORT_DIR          = File.expand_path(File.join(AE_ROOT_DIR,   'import'))
  AE_DEFAULT_IMPORT_FILE = File.expand_path(File.join(AE_IMPORT_DIR, 'automate.xml'))

  def self.instantiate(uri, user)
    $miq_ae_logger.info("MiqAeEngine: Instantiating Workspace for URI=#{uri}")
    workspace, t = Benchmark.realtime_block(:total_time) { MiqAeWorkspaceRuntime.instantiate(uri, user) }
    $miq_ae_logger.info("MiqAeEngine: Instantiating Workspace for URI=#{uri}...Complete - Counts: #{format_benchmark_counts(t)}, Timings: #{format_benchmark_times(t)}")
    workspace
  end

  def self.deliver_queue(args, options = {})
    options = {
      :class_name  => 'MiqAeEngine',
      :method_name => 'deliver',
      :args        => [args],
      :zone        => MiqServer.my_server.has_active_role?('automate') ? MiqServer.my_zone : nil,
      :role        => 'automate',
      :msg_timeout => 60.minutes
    }.merge(options)

    static_keys = [:class_name, :method_name, :zone, :msg_timeout]

    ##############################################
    # IF there is no current message
    # OR any of the static keys in the current message do NOT match the value in the options for the same key,
    # THEN create a new message
    # ELSE requeue the current message with the new options
    ##############################################
    if $_miq_worker_current_msg.nil? || options.any? { |key, value| static_keys.include?(key) ? ($_miq_worker_current_msg.send(key) != value) : false }
      MiqQueue.put(options)
    else
      $_miq_worker_current_msg.requeue(options)
    end
  end

  def self.deliver(*args)
    options = {}

    case args.length
    when 0
      # options = nil
    when 1
      # options = Hash
      options = args.first
    else
      # Legacy
      options[:object_type]      = args.shift
      options[:object_id]        = args.shift
      options[:attrs]            = args.shift
      options[:instance_name]    = args.shift
      options[:user_id]          = args.shift
      options[:state]            = args.shift
      options[:automate_message] = args.shift
      options[:ae_fsm_started]   = args.shift
      options[:ae_state_started] = args.shift
      options[:ae_state_retries] = args.shift
    end

    options[:instance_name] ||= 'AUTOMATION'
    options[:attrs] ||= {}
    user_obj = ae_user_object(options)

    object_type      = options[:object_type]
    object_id        = options[:object_id]
    state            = options[:state]
    user_id          = options[:user_id]
    ae_fsm_started   = options[:ae_fsm_started]
    ae_state_started = options[:ae_state_started]
    ae_state_retries = options[:ae_state_retries]
    ae_state_data    = options[:ae_state_data]
    ae_state_previous = options[:ae_state_previous]
    vmdb_object      = nil
    ae_result        = 'error'

    begin
      object_name = "#{object_type}.#{object_id}"
      _log.info("Delivering #{options[:attrs].inspect} for object [#{object_name}] with state [#{state}] to Automate")
      automate_attrs = options[:attrs].dup

      if object_type
        vmdb_object = object_type.constantize.find_by_id(object_id)
        automate_attrs[create_automation_attribute_key(vmdb_object)] = object_id
        vmdb_object.before_ae_starts(options) if vmdb_object.respond_to?(:before_ae_starts)
      end

      automate_attrs['User::user']      = user_id            unless user_id.nil?
      automate_attrs[:ae_state]         = state              unless state.nil?
      automate_attrs[:ae_fsm_started]   = ae_fsm_started     unless ae_fsm_started.nil?
      automate_attrs[:ae_state_started] = ae_state_started   unless ae_state_started.nil?
      automate_attrs[:ae_state_retries] = ae_state_retries   unless ae_state_retries.nil?
      automate_attrs['ae_state_data']   = ae_state_data      unless ae_state_data.nil?
      automate_attrs['ae_state_previous'] = ae_state_previous  unless ae_state_previous.nil?

      create_automation_object_options = {}
      create_automation_object_options[:vmdb_object] = vmdb_object                unless vmdb_object.nil?
      create_automation_object_options[:class]       = options[:class_name]       unless options[:class_name].nil?
      create_automation_object_options[:namespace]   = options[:namespace]        unless options[:namespace].nil?
      create_automation_object_options[:fqclass]     = options[:fqclass_name]     unless options[:fqclass_name].nil?
      create_automation_object_options[:message]     = options[:automate_message] unless options[:automate_message].nil?
      uri = create_automation_object(options[:instance_name], automate_attrs, create_automation_object_options)
      ws  = resolve_automation_object(uri, user_obj)

      if ws.nil? || ws.root.nil?
        message = "Error delivering #{options[:attrs].inspect} for object [#{object_name}] with state [#{state}] to Automate: Empty Workspace"
        _log.error(message)
        return nil
      end

      ae_result = ws.root['ae_result'] || 'ok'

      unless ae_result.nil?
        if ae_result.casecmp('retry').zero?
          ae_retry_interval = ws.root['ae_retry_interval'].to_s.to_i_with_method
          deliver_on = Time.now.utc + ae_retry_interval

          options[:state]            = ws.root['ae_state'] || state
          options[:ae_fsm_started]   = ws.root['ae_fsm_started']
          options[:ae_state_started] = ws.root['ae_state_started']
          options[:ae_state_retries] = ws.root['ae_state_retries']
          options[:ae_state_data]    = YAML.dump(ws.persist_state_hash) unless ws.persist_state_hash.empty?
          options[:ae_state_previous] = YAML.dump(ws.current_state_info) unless ws.current_state_info.empty?

          message = "Requeuing #{options.inspect} for object [#{object_name}] with state [#{options[:state]}] to Automate for delivery in [#{ae_retry_interval}] seconds"
          _log.info(message)
          deliver_queue(options, :deliver_on => deliver_on)
        else
          if ae_result.casecmp('error').zero?
            message = "Error delivering #{options[:attrs].inspect} for object [#{object_name}] with state [#{state}] to Automate: #{ws.root['ae_message']}"
            _log.error(message)
          end
          MiqAeEvent.process_result(ae_result, automate_attrs) if options[:instance_name].to_s.casecmp('EVENT').zero?
        end
      end

      return ws
    rescue MiqAeException::Error => err
      message = "Error delivering #{automate_attrs.inspect} for object [#{object_name}] with state [#{state}] to Automate: #{err.message}"
      _log.error(message)
    ensure
      vmdb_object.after_ae_delivery(ae_result.to_s.downcase) if vmdb_object.respond_to?(:after_ae_delivery)
    end
  end

  def self.format_benchmark_counts(bm)
    formatted = ''
    bm.keys.select { |k| k.to_s.downcase =~ /_count$/ }.sort_by(&:to_s).each do |k|
      formatted << ', ' unless formatted.blank?
      formatted << "#{k}=>#{bm[k]}"
    end
    "{#{formatted}}"
  end

  BENCHMARK_TIME_THRESHOLD_PERCENT = 5.0 / 100

  def self.format_benchmark_times(bm)
    formatted  = ''
    total_time = bm[:total_time]
    threshold  = 0                                                                               # show everything
    threshold  = (total_time * BENCHMARK_TIME_THRESHOLD_PERCENT) if total_time.kind_of?(Numeric) # only show times > threshold of the total
    bm.keys.select { |k| k.to_s.downcase =~ /_time$/ }.sort_by(&:to_s).each do |k|
      next unless bm[k] >= threshold
      formatted << ', ' unless formatted.blank?
      formatted << "#{k}=>#{bm[k]}"
    end
    "{#{formatted}}"
  end

  def self.create_automation_attribute_class_name(object)
    return object if automation_attribute_is_array?(object)

    case object
    when MiqRequest
      object.class.name
    when MiqRequestTask
      object.class.base_model.name
    when VmOrTemplate
      "VmOrTemplate"
    else
      object.class.base_class.name
    end
  end

  def self.create_automation_attribute_name(object)
    case object
    when MiqRequest
      object.class.name.underscore
    when MiqRequestTask
      object.class.base_model.name.underscore
    when VmOrTemplate
      "vm"
    else
      object.class.base_class.name.underscore
    end
  end

  def self.create_automation_attribute_key(object, attr_name = nil)
    klass_name  = create_automation_attribute_class_name(object)
    return klass_name.to_s if automation_attribute_is_array?(klass_name)
    attr_name ||= create_automation_attribute_name(object)
    "#{klass_name}::#{attr_name}"
  end

  def self.create_automation_attribute_value(object)
    object.id
  end

  def self.automation_attribute_is_array?(attr)
    attr.to_s.downcase.starts_with?("array::")
  end

  def self.create_automation_attributes_string(hash)
    args = create_automation_attributes(hash)
    return args if args.kind_of?(String)
    args.collect { |a| a.join("=") }.join("&")
  end

  def self.create_automation_attributes(hash)
    return hash if hash.kind_of?(String)
    hash.each_with_object({}) do |kv, args|
      key, value = create_automation_attribute(*kv)
      args[key] = value
    end
  end

  def self.create_automation_attribute(key, value)
    case value
    when Array, ActiveRecord::Relation
      [create_automation_attribute_array_key(key), create_automation_attribute_array_value(value)]
    when ActiveRecord::Base
      [create_automation_attribute_key(value, key), create_automation_attribute_value(value)]
    else
      [key, value.to_s]
    end
  end

  def self.create_automation_attribute_array_key(key)
    "Array::#{key}"
  end

  def self.create_automation_attribute_array_value(value)
    value.collect do |obj|
      obj.kind_of?(ActiveRecord::Base) ? "#{obj.class.name}::#{obj.id}" : obj.to_s
    end.join(",")
  end

  def self.set_automation_attributes_from_objects(objects, attrs_hash)
    Array.wrap(objects).compact.each do |object|
      key   = create_automation_attribute_key(object)
      raise "Key: #{key} already exists in hash" if attrs_hash.key?(key)
      value = create_automation_attribute_value(object)
      attrs_hash[key] = value
    end
    attrs_hash
  end

  def self.create_automation_object(name, attrs, options = {})
    # args
    if options[:fqclass]
      options[:namespace], options[:class], = MiqAePath.split(options[:fqclass], :has_instance_name => false)
    else
      options[:namespace] ||= "System"
      options[:class] ||= "Process"
    end
    options[:instance_name] = name

    options[:attrs] = create_ae_attrs(attrs, name, options[:vmdb_object])
    options[:message] = options[:attrs][:message]

    # uri
    path = MiqAePath.new(:ae_namespace => options[:namespace],
                         :ae_class     => options[:class],
                         :ae_instance  => options[:instance_name]).to_s
    MiqAeUri.join(nil, nil, nil, nil, nil, path, nil, options[:attrs], options[:message])
  end

  def self.create_ae_attrs(attrs, name, vmdb_object, objects = [MiqServer.my_server, User.current_user])
    ae_attrs  = attrs.dup
    ae_attrs['object_name'] = name

    # Prepare for conversion to Automate MiqAeService objects (process vmdb_object first in case it is a User or MiqServer)
    ([vmdb_object] + objects).each do |object|
      next if object.nil?
      key           = create_automation_attribute_key(object)
      partial_key   = ae_attrs.keys.detect { |k| k.to_s.ends_with?(key.split("::").last.downcase) }
      next if partial_key # do NOT override any specified
      ae_attrs[key] = create_automation_attribute_value(object)
    end

    ae_attrs["MiqRequest::miq_request"] = vmdb_object.id if vmdb_object.kind_of?(MiqRequest)
    ae_attrs['vmdb_object_type'] = create_automation_attribute_name(vmdb_object) unless vmdb_object.nil?

    array_objects = ae_attrs.keys.find_all { |key| automation_attribute_is_array?(key) }
    array_objects.each do |o|
      ae_attrs[o] = ae_attrs[o].first   if ae_attrs[o].kind_of?(Array)
    end
    ae_attrs
  end

  # side effect in options, :uri is set
  # returns workspace
  def self.resolve_automation_object(uri, user_obj, attr = nil, options = {}, readonly = false)
    raise "User object not passed in" unless user_obj.kind_of?(User)
    uri = create_automation_object(uri, attr, options) if attr
    options[:uri] = uri
    MiqAeWorkspaceRuntime.instantiate(uri, user_obj, :readonly => readonly).tap do
      $miq_ae_logger.debug { ws.to_expanded_xml }
    end
  end

  def self.ae_user_object(options = {})
    raise "user_id not specified in Automation request" if options[:user_id].blank?
    # raise "group_id not specified in Automation request" if options[:miq_group_id].blank?
    User.find_by!(:id => options[:user_id]).tap do |obj|
      # obj.current_group = MiqGroup.find_by!(:id => options[:miq_group_id])
    end
  end
end
