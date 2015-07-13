module MiqAeEvent
  def self.raise_ems_event(event)
    aevent = {
      :event_id   => event.id,
      :event_type => event.event_type,
    }

    if event.source == 'VC'
      aevent.merge!('ExtManagementSystem::ems' => event.ext_management_system.id, :ems_id => event.ext_management_system.id) unless event.ext_management_system.nil?
    end

    aevent.merge!('VmOrTemplate::vm'      => event.src_vm_or_template.id,  :vm_id        => event.src_vm_or_template.id)  unless event.src_vm_or_template.nil?
    aevent.merge!('VmOrTemplate::dest_vm' => event.dest_vm_or_template.id, :dest_vm_id   => event.dest_vm_or_template.id) unless event.dest_vm_or_template.nil?
    aevent.merge!('Host::host'            => event.src_host.id,            :host_id      => event.src_host.id)            unless event.src_host.nil?
    aevent.merge!('Host::dest_host'       => event.dest_host.id,           :dest_host_id => event.dest_host.id)           unless event.dest_host.nil?

    MiqAeEngine.deliver(event.class.name, event.id, aevent, 'Event')
  end

  def self.raise_synthetic_event(event, inputs, message=nil)
    if event == 'vm_retired'
      vm          = inputs[:vm]
      obj_type    = vm.class.name
      obj_id      = vm.id
      instance    = 'Automation'
      aevent      = { 'request' => event }
    else
      obj_type    = nil
      obj_id      = nil
      instance    = 'Event'
      aevent      = self.build_evm_event(event, inputs)
    end

    MiqAeEngine.deliver(obj_type, obj_id, aevent, instance, nil, nil, message)
  end

  def self.raise_evm_event(event_name, target, inputs={}, message=nil)
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by_id(id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" if target.nil?
    end

    MiqAeEngine.deliver(target.class.name, target.id, self.build_evm_event(event_name, inputs), 'Event')
  end

  def self.eval_alert_expression(inputs, message=nil)
    aevent = self.build_evm_event('alert', inputs)
    aevent[:request] = 'evaluate'
    aevent.merge!(inputs)
    ws = MiqAeEngine.deliver(nil, nil, aevent, 'Alert', nil, nil, message)
    return nil if ws.nil? || ws.root.nil?
    return ws.root['ae_result']
  end

  def self.build_evm_event(event, passed_inputs={})
    inputs = passed_inputs.dup

    $miq_ae_logger.info("MiqAeEvent.build_evm_event >> event=<#{event.inspect}> inputs=<#{inputs.inspect}>")
    event_type = event.respond_to?(:name) ? event.name : event
    aevent = { :event_type => event_type }

    [
      { :key => :vm,     :name => 'vm',         :class => VmOrTemplate },
      { :key => :ems,    :name => 'ems',        :class => ExtManagementSystem },
      { :key => :host,   :name => 'host',       :class => Host },
      { :key => :policy, :name => 'miq_policy', :class => MiqPolicy}
    ].each do |hash|
      next if inputs[hash[:key]].nil?

      if inputs[hash[:key]].kind_of?(Hash)
        input = inputs.delete(hash[:key])
        raise "Unexpected class #{input[:vmdb_class]} for #{hash[:key]} -- expected class=#{hash[:class].name}" if input[:vmdb_class] != hash[:class].name
        raise "Invalid vmdb_id=#{input[:vmdb_id].inspect} for #{hash[:key]}" unless input[:vmdb_id].kind_of?(Numeric)

        vmdb_object = hash[:class].find_by_id(input[:vmdb_id])
        raise "VMDB Object not found" if vmdb_object.nil?
      elsif inputs[hash[:key]].kind_of?(hash[:class])
        vmdb_object = inputs.delete(hash[:key])
      else
        raise "Unexpected class #{inputs[hash[:key]].class.name} for #{hash[:key]} -- expected class=#{hash[:class].name}"
      end

      aevent.merge!("#{hash[:class].name}::#{hash[:name]}" => vmdb_object.id, "#{hash[:key]}_id".to_sym  => vmdb_object.id)
    end

    return aevent.merge(inputs)
  end

  def self.process_result(ae_result, aevent)
    begin
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeEngine::MiqAeUri.split(ae_result)
      args = MiqAeEngine::MiqAeUri.query2hash(query)

      if scheme.casecmp('miqpeca').zero?
        # Pass to policy
        #   Sample URI: 'miqpeca:///event?logical_event=vm_retire_warn'
        # inputs were either passed through EVM eveny (aka policy event) of fabricated (below) from an EMS event
        inputs = aevent.delete(:inputs)

        # TODO: Need to setup inputs for policy.
        unless inputs
          inputs = {}
          inputs[:vm]                    = Vm.find_by_id(aevent[:vm_id])                   unless aevent[:vm_id].nil?
          inputs[:host]                  = Host.find_by_id(aevent[:host_id])               unless aevent[:host_id].nil?
          inputs[:ext_management_system] = ExtManagementSystem.find_by_id(aevent[:ems_id]) unless aevent[:ems_id].nil?
        end

        target     = inputs.delete(:target) || inputs['vm']
        event_name = args['logical_event']  || aevent[:event_type]
        $miq_ae_logger.info("Enforcing Policy [#{ae_result}]")
        MiqPolicy.enforce_policy(target, event_name, inputs) unless target.nil?
      end
    rescue URI::InvalidURIError => err
    end
  end
end
