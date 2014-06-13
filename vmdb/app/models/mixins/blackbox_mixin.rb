# This is blackbox code for VM that is not presently being used.

module BlackboxMixin
  # Call the VmSynchronize Job
  # TODO: Is this still being used?
  def sync(userid = "system", options={})
    options = {
      :target_id => self.id,
      :target_class => self.class.base_class.name,
      :name => "Synchronize data for Vm #{self.name}",
      :userid => userid,
      :categories => self.class.default_scan_categories
    }.merge(options)
    options = {:agent_id => myhost.id, :agent_class => myhost.class.to_s}.merge!(options) unless myhost.nil?

    $log.info "MIQ(Vm-sync) SYNCHRONIZE [#{options[:categories].inspect}] [#{options[:categories].class}]"
    begin
      job = Job.create_job("VmSynchronize", options)
      validate_blackbox()
      return job
    rescue => err
      $log.log_backtrace(err)
      raise
    end
  end

  def record_blackbox_event(eventData)
    return false # temporarily disabling until we can work out coordination of proxy access to vm disk file during VC activity.
    return false unless eventData.class == Hash

    hosts = self.storage2active_proxies
    if hosts.empty?
      $log.debug("MIQ(vm-record_blackbox_event): Skipping record_blackbox_event, no active proxy")
      return false
    end

    host = hosts.first # use first host on list since we don't have a dispatcher for this.
    begin
      host.call_ws(OpenStruct.new("args"=>[self.path, YAML.dump(eventData)], "useHostQueue"=>true, "method_name"=>"RecordBlackBoxEvent"))
    rescue => err
      $log.log_backtrace(err)
    end
  end

  def delete_blackbox(userid = "system")
    raise "The VM needs to be in a Powered Off state to delete the BlackBox." unless ["off","unknown"].include?(self.current_state)
    create_blackbox_job("delete", userid)
  end

  def create_blackbox(userid = "system")
    create_blackbox_job("create", userid)
  end

  def validate_blackbox(userid = "system", opts = nil)
    #
    # This method has been disabled since blackbox support has been disabled in the UI
    #
    #options = {:force => false}
    #options.merge!(opts) unless opts.nil?
    #create_blackbox_job("validate", userid) if options[:force] || self.blackbox_validated == 0
  end

  def create_blackbox_job(mode, userid)
    # Start the Blackbox manager job
    begin
      options = {
        :target_id => self.id,
        :target_class => self.class.base_class.name,
        :name => "#{mode.capitalize} Blackbox for Vm #{self.name}",
        :userid => userid,
        :mode=>mode
      }
      options = {:agent_id => myhost.id, :agent_class => myhost.class.to_s}.merge!(options) unless myhost.nil?

      job = Job.create_job("BlackBoxMgr", options)
    rescue => err
      $log.log_backtrace(err)
    end
  end

  def blackbox_manager_ws(options)
    # Skip local configuration if we are running against a VMFS datastore
    # We need to call a WS once the blackbox disk file is in place.
    config_locally = self.storage.store_type == "VMFS" ? false : true
    eventData = {:config => {:vmId=>self.guid, :svrId=>MiqServer.my_guid, :path=>self.path},
      :options => {:config_locally=>config_locally, :jobid=>options["taskid"]}}

    run_miq_cmd(options[:ws_method], options, [YAML.dump(eventData)])
  end

  def process_blackbox_summary(xmlNode, jobid)
    $log.debug("MIQ(vm-process_blackbox_summary): XML node received [#{xmlNode.to_s}]")
    returnHash = YAML.load(xmlNode.attributes["return"].to_s)
    configHash, resultsHash = returnHash[:config], returnHash[:results]

    $log.info("MIQ(vm-process_blackbox_summary): Returned Hash [#{returnHash.inspect}]")

    # Check if an error occurred while processing on the host
    raise resultsHash[:error_message] if resultsHash.is_a?(Hash) && resultsHash[:error] == true

    if configHash.is_a?(Hash)
      # The history array will contain information about our genealogy
      if configHash[:history]
        parent = configHash[:history][1]
        if parent
          parentVm = Vm.find_by_guid(parent[:vmId])
          parentVm.set_child(self) if parentVm
        end
      end

      # The exist flag tells us if the blackbox exists on disk
      # Update VM row to reflect current blackbox state
      if returnHash[:results][:exists] && returnHash[:results][:configured]
        self.blackbox_exists = true
      else
        self.blackbox_exists = false
      end

      # If we made it here we have validated the blackbox
      self.blackbox_validated = 1
      self.save

      # The created flag reports that the blackbox was created as a result of the ws call.
      if returnHash[:results][:exists]
        if xmlNode.name.downcase.include?("delete")
          remove_blackbox_from_vm_config(returnHash) if returnHash[:results][:configured]
        else
          add_blackbox_to_vm_config(returnHash) if !returnHash[:results][:configured]
        end
      end
    end
  end

  def remove_blackbox_from_vm_config(dataHash)
    # For VMware VMs that are associated to VC call the ws to remove the disk
    if self.storage.store_type == "VMFS"
      verb = "removeDiskByFile"
      if self.ext_management_system && self.ext_management_system.authentication_valid? && ExtManagementSystem::VERBS.include?(verb)
        $log.info("MIQ(remove_blackbox_from_vm_config) Invoking [#{verb}] through EMS: [#{self.ext_management_system.name}]")

        bbDiskName = File.join(File.dirname(self.path), File.basename(dataHash[:results][:bbName]))

        # Call addDisk and pass the existing blackbox filename and a size of -1 to indicate it already exists.
        self.ext_management_system.removeDiskByFile(self, {:diskName=>bbDiskName})
        self.blackbox_exists = false
        self.save
      end
    end
  end

  def add_blackbox_to_vm_config(dataHash)
    # For VMware VMs that are associated to VC call the ws to add the
    if self.storage.store_type == "VMFS"
      verb = "addDisk"
      if self.ext_management_system && self.ext_management_system.authentication_valid? && ExtManagementSystem::VERBS.include?(verb)
        $log.info("MIQ(add_blackbox_to_vm_config) Invoking [#{verb}] through EMS: [#{self.ext_management_system.name}]")

        bbDiskName = File.join(File.dirname(self.path), File.basename(dataHash[:results][:bbName]))

        # Call addDisk and pass the existing blackbox filename and a size of -1 to indicate it already exists.
        self.ext_management_system.addDisk(self, {:diskName=>bbDiskName, :diskSize=>-1})
        self.blackbox_exists = true
        self.save
      end
    end
  end
end
