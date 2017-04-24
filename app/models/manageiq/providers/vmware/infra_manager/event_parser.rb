module ManageIQ::Providers::Vmware::InfraManager::EventParser
  def self.event_to_hash(event, ems_id = nil)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?

    _log.debug { "#{log_header}event: [#{event.inspect}]" }
    event_type = event['eventType']
    if event_type.nil?
      _log.error("#{log_header}eventType missing in event: [#{event.inspect}]")
      raise MiqException::Error, "event must have an eventType"
    end

    chain_id = event['chainId']
    if chain_id.nil?
      _log.error("#{log_header}chainId missing in event: [#{event.inspect}]")
      raise MiqException::Error, "event must have a chain_id"
    end

    is_task = (event_type == 'TaskEvent')
    if is_task
      changed_event = false

      sub_event_type = event.fetch_path('info', 'name')

      # Handle special cases
      case sub_event_type
      when nil
        # Handle cases where event name is missing
        sub_event_type = 'PowerOnVM_Task'    if event['fullFormattedMessage'].to_s.downcase == 'task: power on virtual machine'
        sub_event_type = 'DrsMigrateVM_Task' if sub_event_type.nil? && event.fetch_path('info', 'descriptionId') == 'Drm.ExecuteVMotionLRO'
        if sub_event_type.nil?
          _log.warn("#{log_header}Event Type cannot be determined for TaskEvent. Using generic eventType [TaskEvent] instead. event: [#{event.inspect}]")
          sub_event_type = 'TaskEvent'
        end
      when 'Rename_Task', 'Destroy_Task'
        # Handle case where event name is overloaded
        sub_event_name = event.fetch_path('info', 'descriptionId').split('.').first
        sub_event_name = case sub_event_name
                         when 'VirtualMachine' then 'VM'
                         when 'ClusterComputeResource' then 'Cluster'
                         else sub_event_name
                         end
        sub_event_type.gsub!(/_/, "#{sub_event_name}_")
      when 'MarkAsTemplate', 'MarkAsVirtualMachine'
        # Handle case where, due to timing issues, the data may not be as expected
        path_from, path_to = (sub_event_type == 'MarkAsTemplate' ? ['.vmtx', '.vmx'] : ['.vmx', '.vmtx'])

        path = event.fetch_path('vm', 'path')
        if !path.nil? && path[-(path_from.length)..-1] == path_from
          path[-(path_from.length)..-1] = path_to
          changed_event = true
        end
      end
      _log.debug { "#{log_header}changed event: [#{event.inspect}]" } if changed_event

      event_type = sub_event_type
    elsif event_type == "EventEx"
      sub_event_type = event['eventTypeId']
      event_type = sub_event_type unless sub_event_type.blank?
    end

    # Build the event hash
    result = {
      :event_type => event_type,
      :chain_id   => chain_id,
      :is_task    => is_task,
      :source     => 'VC',

      :message    => event['fullFormattedMessage'],
      :timestamp  => event['createdTime'],
      :full_data  => event
    }
    result[:ems_id] = ems_id unless ems_id.nil?
    result[:username] = event['userName'] unless event['userName'].blank?

    # Get the vm information
    vm_key = 'vm' if event.key?('vm')
    vm_key = 'sourceVm' if event.key?('sourceVm')
    vm_key = 'srcTemplate' if event.key?('srcTemplate')
    unless vm_key.nil?
      vm_data = event[vm_key]
      vm_ems_ref = vm_data['vm']
      result[:vm_ems_ref] = vm_ems_ref.to_s unless vm_ems_ref.nil?
      vm_name = vm_data['name']
      result[:vm_name] = URI.decode(vm_name) unless vm_name.nil?
      vm_location = vm_data['path']
      result[:vm_location] = vm_location unless vm_location.nil?
    end

    # Get the dest vm information
    has_dest = false
    if ['sourceVm', 'srcTemplate'].include?(vm_key)
      vm_data = event['vm']
      unless vm_data.nil?
        vm_ems_ref = vm_data['vm']
        result[:dest_vm_ems_ref] = vm_ems_ref.to_s unless vm_ems_ref.nil?
        vm_name = vm_data['name']
        result[:dest_vm_name] = URI.decode(vm_name) unless vm_name.nil?
        vm_location = vm_data['path']
        result[:dest_vm_location] = vm_location unless vm_location.nil?
      end

      has_dest = true
    elsif event.key?('destName')
      result[:dest_vm_name] = event['destName']
      has_dest = true
    end

    # Get the host information
    host_name = event.fetch_path('host', 'name')
    result[:host_name] = host_name unless host_name.nil?
    host_ems_ref = event.fetch_path('host', 'host')
    result[:host_ems_ref] = host_ems_ref.to_s unless host_ems_ref.nil?

    # Get the dest host information
    if has_dest
      host_data = event['destHost'] || event['host']
      unless host_data.nil?
        host_ems_ref = event['host']
        result[:dest_host_ems_ref] = host_ems_ref.to_s unless host_ems_ref.nil?
        host_name = event['name']
        result[:dest_host_name] = host_name unless host_name.nil?
      end
    end

    result
  end

  def self.obj_update_to_hash(event)
    obj_type = event[:objType]

    method = "#{obj_type.downcase}_update_to_hash"
    public_send(method, event) if respond_to?(method)
  end

  def self.folder_update_to_hash(event)
    mor = event[:mor]
    {
      :folder => {
        :type        => 'EmsFolder',
        :ems_ref     => mor,
        :ems_ref_obj => mor,
        :uid_ems     => mor
      }
    }
  end
end
