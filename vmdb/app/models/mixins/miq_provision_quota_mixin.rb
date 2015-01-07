module MiqProvisionQuotaMixin

  # Supported quota types
  # vm_by_owner, vm_by_group
  # provision_by_owner, provision_by_group
  # requset_by_owner, request_by_group
  def check_quota(quota_type=:vms_by_owner, options={})
    quota_method = "quota_#{quota_type}"
    raise "check_quota called with an invalid provisioning quota method <#{quota_type}>" unless self.respond_to?(quota_method)
    self.send(quota_method, options)
  end

  # Collect stats about VMs in the same LDAP group as the owner making the request
  def quota_vms_by_group(options)
    return quota_vm_stats(:quota_find_vms_by_group, options)
  end

  # Collect stats about VMs assigned to the owner making the request
  def quota_vms_by_owner(options)
    return quota_vm_stats(:quota_find_vms_by_owner, options)
  end

  def quota_vms_by_owner_and_group(options)
    return quota_vm_stats(:quota_find_vms_by_owner_and_group, options)
  end

  # Collect stats about retired VMs that have not been deleted and are in the same LDAP group as the owner
  # making the request
  def quota_retired_vms_by_group(options)
    return quota_vm_stats(:quota_find_retired_vms_by_group, options)
  end

  # Collect stats about retired VMs that have not been deleted and are assigned to the owner making the request
  def quota_retired_vms_by_owner(options)
    return quota_vm_stats(:quota_find_retired_vms_by_owner, options)
  end

  def quota_retired_vms_by_owner_and_group(options)
    return quota_vm_stats(:quota_find_retired_vms_by_owner_and_group, options)
  end

  # Collect stats based on provisions running on the same day as this request and
  # in the same LDAP group as the owner.
  def quota_provisions_by_group(options)
    return quota_provision_stats(:quota_find_provision_by_group, options)
  end

  # Collect stats based on provisions running on the same day as this request by
  # the same owner.
  def quota_provisions_by_owner(options)
    return quota_provision_stats(:quota_find_provision_by_owner, options)
  end

  # Collect stats based on provision requests made today by the same LDAP group, regardless
  # of when the provision request is scheduled to run.
  def quota_requests_by_group(options)
    return quota_provision_stats(:quota_find_prov_request_by_group, options)
  end

  # Collect stats based on provision requests made today by the same owner, regardless
  # of when the provision request is scheduled to run.
  def quota_requests_by_owner(options)
    return quota_provision_stats(:quota_find_prov_request_by_owner, options)
  end

  # Collect stats based on currently active provision requests for users in the same LDAP group as the owner.
  def quota_active_provisions_by_group(options)
    return quota_provision_stats(:quota_find_active_prov_request_by_group, options.merge(:nil_vm_id_only => true))
  end

  # Collect stats based on currently active provision requesets for the same owner.
  def quota_active_provisions_by_owner(options)
    return quota_provision_stats(:quota_find_active_prov_request_by_owner, options.merge(:nil_vm_id_only => true))
  end

  def quota_active_provisions(options)
    return quota_provision_stats(:quota_find_active_prov_request, options.merge(:nil_vm_id_only => true))
  end

  def quota_find_vms_by_group(options)
    vms = []
    prov_owner = self.get_owner
    unless prov_owner.nil?
      vms = Vm.where("miq_group_id = ?", prov_owner.current_group_id).includes(:hardware => :disks)
      vms.reject! do |vm|
        result = vm.template? || vm.host_id.nil?
        # if result is already true we can skip the following checks
        unless result == true
          result = if options[:retired_vms_only] == true
                     !vm.retired?
                   elsif options[:include_retired_vms] == false
                     # Skip retired VMs by default
                     vm.retired?
                   else
                     result
                   end
        end
        result
      end
    end
    return vms
  end

  def quota_find_vms_by_owner_and_group(options)
    vms = []
    prov_owner = self.get_owner
    unless prov_owner.nil?
      vms = Vm.user_or_group_owned(prov_owner)
      MiqPreloader.preload(vms, :hardware => :disks)
      vms.reject! do |vm|
        result = vm.template? || vm.host_id.nil?
        # if result is already true we can skip the following checks
        unless result == true
          result = if options[:retired_vms_only] == true
                     !vm.retired?
                   elsif options[:include_retired_vms] == false
                     # Skip retired VMs by default
                     vm.retired?
                   else
                     result
                   end
        end
        result
      end
    end
    return vms
  end

  def quota_find_vms_by_owner(options)
    vms = []
    prov_owner = self.get_owner
    unless prov_owner.nil?
      cond_str, cond_args  = "evm_owner_id = ? AND template = ? AND host_id is not NULL", [prov_owner.id, false]

      # Default return includes retired VMs that are still on a host
      if options[:retired_vms_only] == true
         cond_str += " AND retired = ?"
         cond_args << true
      elsif options[:include_retired_vms] == false
         # Skip retired VMs
         cond_str += " AND (retired is NULL OR retired = ?)"
         cond_args << false
      end

      vms = Vm.where(cond_str, *cond_args).includes(:hardware => :disks).to_a
    end
    return vms
  end

  def quota_find_retired_vms_by_group(options)
    quota_find_vms_by_group(options.merge(:retired_vms_only => true))
  end

  def quota_find_retired_vms_by_owner(options)
    quota_find_vms_by_owner(options.merge(:retired_vms_only => true))
  end

  def quota_find_retired_vms_by_owner_and_group(options)
    quota_find_vms_by_owner_and_group(options.merge(:retired_vms_only => true))
  end

  def quota_vm_stats(vms_method, options)
    result = {:count => 0, :memory => 0, :cpu => 0, :snapshot_storage => 0, :used_storage => 0, :allocated_storage => 0, :ids => [], :class_name => Vm.name}
    vms = self.send(vms_method, options)
    result[:count] = vms.length
    vms.each do |vm|
      result[:memory]            += vm.ram_size.to_i
      result[:cpu]               += vm.num_cpu
      result[:snapshot_storage]  += vm.snapshot_storage
      result[:used_storage]      += vm.used_disk_storage.to_i + vm.snapshot_storage
      result[:allocated_storage] += vm.allocated_disk_storage.to_i
      result[:ids] << vm.id
    end
    return result
  end

  def quota_get_time_range(time=nil)
    tz = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC"
    ts = time.nil? ? Time.now.in_time_zone(tz) : time.in_time_zone(tz)
    return [ts.beginning_of_day.utc, ts.end_of_day.utc]
  end

  def quota_find_provisions(options)
    scheduled_range = self.quota_get_time_range(options[:scheduled_time])
    scheduled_today = scheduled_range.first == self.quota_get_time_range().first

    queued_requests = MiqQueue.find(:all, :conditions => ["class_name = 'MiqProvisionRequest' and method_name = 'create_provision_instances' and state = 'ready' and (deliver_on >= ? and deliver_on < ?)",
                                *scheduled_range])
    # Make sure we skip the current MiqProvisionRequest in the calculation.
    skip_id = self.class.name == "MiqProvisionRequest" ? self.id : self.miq_provision_request.id
    load_ids = queued_requests.collect {|q| q.instance_id}
    load_ids.delete(skip_id)
    provisions = MiqProvisionRequest.find_all_by_id(load_ids)

    # If the schedule is for today we need to add in provisions that ran today (scheduled or immediate)
    if scheduled_today
      today_range = (scheduled_range.first..scheduled_range.last)
      MiqProvisionRequest.find(:all, :conditions => ["request_state != 'pending' and (updated_on >= ? and updated_on < ?)", *scheduled_range]).each do |prov_req|
        next if prov_req.id == skip_id
        provisions << prov_req if today_range.include?(prov_req.options[:delivered_on])
      end
    end

    return provisions
  end

  def quota_find_provision_by_owner(options)
    email = get_option(:owner_email).to_s.strip
    sched_type = get_option(:schedule_type).to_s.strip
    options[:scheduled_time] = sched_type == 'schedule' ? get_option(:schedule_time) : nil
    return quota_find_provisions(options).delete_if {|p| email.casecmp(p.get_option(:owner_email).to_s.strip) != 0}
  end

  def quota_find_provision_by_group(options)
    prov_requests = []
    prov_owner = self.get_owner
    unless prov_owner.nil?
      group = prov_owner.ldap_group
      sched_type = get_option(:schedule_type).to_s.strip
      options[:scheduled_time] = sched_type == 'schedule' ? get_option(:schedule_time) : nil
      prov_requests = quota_find_provisions(options).delete_if do |p|
        prov_req_owner = p.get_owner
        prov_req_owner.nil? ? true : group.casecmp(prov_req_owner.ldap_group) != 0
      end
    end
    return prov_requests
  end

  def quota_find_prov_requests(options)
    today_time_range = self.quota_get_time_range()
    requests = MiqRequest.find(:all, :conditions => ["type = ? and approval_state != ? and (created_on >= ? and created_on < ?)",
                                MiqProvisionRequest.name, 'denied', *today_time_range])
    # Make sure we skip the current MiqProvisionRequest in the calculation.
    skip_id = self.class.name == "MiqProvisionRequest" ? self.id : self.miq_provision_request.id
    return requests.collect {|request| request unless request.id == skip_id}.compact
  end

  def quota_find_prov_request_by_owner(options)
    email = get_option(:owner_email).to_s.strip
    return quota_find_prov_requests(options).delete_if {|p| email.casecmp(p.get_option(:owner_email).to_s.strip) != 0}
  end

  def quota_find_prov_request_by_group(options)
    prov_requests = []
    prov_owner = self.get_owner
    unless prov_owner.nil?
      group = prov_owner.ldap_group
      prov_requests = quota_find_prov_requests(options).delete_if do |p|
        prov_req_owner = p.get_owner
        prov_req_owner.nil? ? true : group.casecmp(prov_req_owner.ldap_group) != 0
      end
    end
    return prov_requests
  end

  def quota_find_active_prov_request_by_owner(options)
    email = get_option(:owner_email).to_s.strip
    return quota_find_active_prov_request(options).delete_if {|p| email.casecmp(p.get_option(:owner_email).to_s.strip) != 0}
  end

  def quota_find_active_prov_request_by_group(options)
    prov_requests = []
    prov_owner = self.get_owner
    unless prov_owner.nil?
      group = prov_owner.ldap_group
      prov_requests = quota_find_active_prov_request(options).delete_if do |p|
        prov_req_owner = p.get_owner
        prov_req_owner.nil? ? true : group.casecmp(prov_req_owner.ldap_group) != 0
      end
    end
    return prov_requests
  end

  def quota_find_active_prov_request(options)
    prov_req_ids = []
    MiqQueue.find(:all, :conditions => {:method_name => 'create_provision_instances', :state => 'dequeue', :class_name => 'MiqProvisionRequest'}).each do |q|
      prov_req_ids << q.instance_id
    end

    prov_ids = []
    MiqQueue.find(:all, :conditions => ["method_name = ? AND state in (?) AND class_name = ? AND task_id like ?", 'deliver', ['ready','dequeue'], 'MiqAeEngine', '%miq_provision_%']).each do |q|
      if !q.args.nil?
        args = q.args.first
        prov_ids << args[:object_id] if args[:object_type] == 'MiqProvision' && !args[:object_id].blank?
      end
    end
    MiqProvision.find(:all, :conditions => ["id in (?)", prov_ids], :select => "id,miq_request_id").each do |p|
      prov_req_ids << p.miq_request_id
    end

    return MiqProvisionRequest.find_all_by_id(prov_req_ids.compact.uniq)
  end

  def quota_provision_stats(prov_method, options)
    result = {:count => 0, :memory => 0, :cpu => 0, :storage => 0, :ids => [], :class_name => MiqProvisionRequest.name,
              :active => {
                :class_name => MiqProvision.name, :ids => [], :storage_by_id => Hash.new {|k,v| k[v] = 0},
                :memory_by_host_id => Hash.new {|k,v| k[v] = 0},  :cpu_by_host_id => Hash.new {|k,v| k[v] = 0},
                :vms_by_storage_id => Hash.new {|k,v| k[v] = []}
              }
             }

    self.send(prov_method, options).each do |pr|
      num_vms_for_request = pr.get_option(:number_of_vms).to_i
      if options[:nil_vm_id_only] == true && pr.miq_request_tasks.length == num_vms_for_request
        no_vm = pr.miq_request_tasks.find_all {|p| p.destination_id.nil? && p.state != 'finished' }
        num_vms_for_request = no_vm.length
      end

      unless num_vms_for_request.zero?
        new_disk_storage_size = pr.get_new_disks.inject(0){|s,d| s += d[:sizeInMB].to_i} * 1.megabyte
        result[:count]   += num_vms_for_request
        result[:memory]  += pr.get_option(:vm_memory).to_i      * num_vms_for_request
        result[:cpu]     += pr.get_option(:number_of_cpus).to_i * num_vms_for_request
        result[:storage] += (pr.vm_template.allocated_disk_storage.to_i + new_disk_storage_size) * num_vms_for_request
        result[:ids] << pr.id

        # Include a resource breakdown for actively provisioning records
        pr.miq_request_tasks.each do |p|
          next unless p.state == 'active'
          host_id, storage_id = p.get_option(:dest_host).to_i, p.get_option(:dest_storage).to_i
          active = result[:active]
          active[:memory_by_host_id][host_id] += p.get_option(:vm_memory).to_i
          active[:cpu_by_host_id][host_id]    += p.get_option(:number_of_cpus).to_i
          active[:storage_by_id][storage_id]  += p.vm_template.allocated_disk_storage.to_i + new_disk_storage_size
          active[:vms_by_storage_id][storage_id] << p.id
          active[:ids] << p.id
        end
      end
    end
    return result
  end

end
