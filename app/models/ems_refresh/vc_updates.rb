module EmsRefresh::VcUpdates
  OBJ_TYPE_TO_TYPE_AND_CLASS = {
    'VirtualMachine' => [:vm,   VmOrTemplate],
    'HostSystem'     => [:host, Host]
  }

  def queue_vc_update(ems, event)
    ems = ExtManagementSystem.extract_objects(ems)
    return if ems.nil?

    MiqQueue.put(
      :queue_name  => MiqEmsRefreshWorker.queue_name_for_ems(ems),
      :class_name  => 'EmsRefresh',
      :method_name => 'vc_update',
      :role        => "ems_inventory",
      :zone        => ems.my_zone,
      :args        => [ems.id, event]
    )
  end

  def vc_update(ems_id, event)
    return unless event.kind_of?(Hash)
    method = "vc_#{event[:op].to_s.underscore}_event"
    send(method, ems_id, event) if self.respond_to?(method)
  end

  def vc_update_event(ems_id, event)
    obj_type, mor = event.values_at(:objType, :mor)

    type, klass = OBJ_TYPE_TO_TYPE_AND_CLASS[obj_type]
    return if type.nil?

    obj = klass.find_by(:ems_ref => mor, :ems_id => ems_id)
    return if obj.nil?

    change_set = event[:changeSet]
    handled, unhandled = change_set.partition { |c| EmsRefresh::VcUpdates.has_handler?(type, c["name"]) }

    if handled.any?
      _log.info("Handling direct updates for properties: #{handled.collect { |c| c["name"] }.inspect}")
      handled.each { |c| EmsRefresh::VcUpdates.handler(type, c["name"]).call(obj, c["val"]) }
      obj.save!
    end

    if unhandled.any?
      _log.info("Queueing refresh for #{obj.class} id: [#{obj.id}], EMS id: [#{ems_id}] on event [#{obj_type}-update] for properties #{unhandled.inspect}")
      EmsRefresh.queue_refresh(obj)
    end
  end

  def vc_create_event(ems_id, event)
    # TODO: Implement
    _log.debug("Ignoring refresh for EMS id: [#{ems_id}] on event [#{event[:objType]}-create]")
    nil
  end

  def vc_delete_event(ems_id, event)
    # TODO: Implement
    _log.debug("Ignoring refresh for EMS id: [#{ems_id}] on event [#{event[:objType]}-delete]")
    nil
  end

  #
  # VC helper methods
  #

  #
  # Direct update methods
  #

  def self.parse_vm_template(vm, val)
    vm.template = val.to_s.downcase == "true"
  end

  def self.parse_vm_power_state(vm, val)
    vm.raw_power_state = vm.template? ? "never" : val
  end

  def self.has_handler?(type, prop)
    PARSING_HANDLERS.has_key_path?(type, prop)
  end

  def self.handler(type, prop)
    PARSING_HANDLERS.fetch_path(type, prop)
  end

  PARSING_HANDLERS = {
    :vm => {
      "summary.runtime.powerState" => method(:parse_vm_power_state),
      "summary.config.template"    => method(:parse_vm_template)
    }
  }
end
