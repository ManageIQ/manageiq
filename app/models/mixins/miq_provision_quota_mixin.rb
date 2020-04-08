module MiqProvisionQuotaMixin
  # Supported quota types
  # vm_by_owner, vm_by_group
  # provision_by_owner, provision_by_group
  # request_by_owner, request_by_group

  def check_quota(quota_type = :vms_by_owner, options = {})
    quota_method = "quota_#{quota_type}"
    unless respond_to?(quota_method)
      raise _("check_quota called with an invalid provisioning quota method <%{type}>") % {:type => quota_type}
    end
    send(quota_method, options)
  end

  # Collect stats about VMs in the same LDAP group as the owner making the request
  def quota_vms_by_group(options)
    quota_vm_stats(:quota_find_vms_by_group, options)
  end

  # Collect stats about VMs assigned to the owner making the request
  def quota_vms_by_owner(options)
    quota_vm_stats(:quota_find_vms_by_owner, options)
  end

  def quota_vms_by_owner_and_group(options)
    quota_vm_stats(:quota_find_vms_by_owner_and_group, options)
  end

  # Collect stats about retired VMs that have not been deleted and are in the same LDAP group as the owner
  # making the request
  def quota_retired_vms_by_group(options)
    quota_vm_stats(:quota_find_retired_vms_by_group, options)
  end

  # Collect stats about retired VMs that have not been deleted and are assigned to the owner making the request
  def quota_retired_vms_by_owner(options)
    quota_vm_stats(:quota_find_retired_vms_by_owner, options)
  end

  def quota_retired_vms_by_owner_and_group(options)
    quota_vm_stats(:quota_find_retired_vms_by_owner_and_group, options)
  end

  # Collect stats based on provisions running on the same day as this request and
  # in the same LDAP group as the owner.
  def quota_provisions_by_group(options)
    quota_provision_stats(:quota_find_provision_by_group, options)
  end

  # Collect stats based on provisions running on the same day as this request by
  # the same owner.
  def quota_provisions_by_owner(options)
    quota_provision_stats(:quota_find_provision_by_owner, options)
  end

  # Collect stats based on provision requests made today by the same LDAP group, regardless
  # of when the provision request is scheduled to run.
  def quota_requests_by_group(options)
    quota_provision_stats(:quota_find_prov_request_by_group, options)
  end

  # Collect stats based on provision requests made today by the same owner, regardless
  # of when the provision request is scheduled to run.
  def quota_requests_by_owner(options)
    quota_provision_stats(:quota_find_prov_request_by_owner, options)
  end

  # Collect stats based on currently active provision requests for users in the same LDAP group as the owner.
  def quota_active_provisions_by_group(options)
    quota_provision_stats(:quota_find_active_prov_request_by_group, options.merge(:nil_vm_id_only => true))
  end

  # Collect stats based on currently active provision requests for user tenant.
  def quota_active_provisions_by_tenant(options)
    quota_provision_stats(:quota_find_active_prov_request_by_tenant, options.merge(:nil_vm_id_only => true))
  end

  # Collect stats based on currently active provision requesets for the same owner.
  def quota_active_provisions_by_owner(options)
    quota_provision_stats(:quota_find_active_prov_request_by_owner, options.merge(:nil_vm_id_only => true))
  end

  def quota_active_provisions(options)
    quota_provision_stats(:quota_find_active_prov_request, options.merge(:nil_vm_id_only => true))
  end

  def quota_find_vms_by_group(options)
    vms = []
    prov_owner = get_owner
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
    vms
  end

  def quota_find_vms_by_owner_and_group(options)
    scope = Vm.where.not(:host_id => nil)
    if options[:retired_vms_only] == true
      scope = scope.where(:retired => true)
    elsif options[:include_retired_vms] == false
      scope = scope.where.not(:retired => true)
    end

    scope.user_or_group_owned(prov_owner, prov_owner.current_group).includes(:hardware => :disks).to_a
  end

  def quota_find_vms_by_owner(options)
    vms = []
    prov_owner = get_owner
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
    vms
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
    result = {:count => 0, :memory => 0, :cpu => 0, :snapshot_storage => 0, :used_storage => 0, :allocated_storage => 0, :ids => [], :class_name => "Vm"}
    vms = send(vms_method, options)
    result[:count] = vms.length
    vms.each do |vm|
      result[:memory] += vm.ram_size.to_i
      result[:cpu] += vm.cpu_total_cores
      result[:snapshot_storage] += vm.snapshot_storage
      result[:used_storage] += vm.used_disk_storage.to_i + vm.snapshot_storage
      result[:allocated_storage] += vm.allocated_disk_storage.to_i
      result[:ids] << vm.id
    end
    result
  end

  def quota_get_time_range(time = nil)
    tz = MiqServer.my_server.server_timezone
    ts = time.nil? ? Time.now.in_time_zone(tz) : time.in_time_zone(tz)
    [ts.beginning_of_day.utc, ts.end_of_day.utc]
  end

  def quota_find_provisions(options)
    scheduled_range = quota_get_time_range(options[:scheduled_time])
    scheduled_today = scheduled_range.first == quota_get_time_range.first

    queued_requests = MiqQueue.where(
      :class_name  => 'MiqProvisionRequest',
      :method_name => 'create_request_tasks',
      :state       => 'ready',
      :deliver_on  => scheduled_range,
    )

    # Make sure we skip the current MiqProvisionRequest in the calculation.
    skip_id = self.class.name == "MiqProvisionRequest" ? id : miq_provision_request.id
    load_ids = queued_requests.pluck(:instance_id)
    load_ids.delete(skip_id)
    provisions = MiqProvisionRequest.where(:id => load_ids).to_a

    # If the schedule is for today we need to add in provisions that ran today (scheduled or immediate)
    if scheduled_today
      today_range = (scheduled_range.first..scheduled_range.last)
      MiqProvisionRequest.where.not(:request_state => 'pending').where(:updated_on => today_range).each do |prov_req|
        next if prov_req.id == skip_id
        provisions << prov_req if today_range.include?(prov_req.options[:delivered_on])
      end
    end

    provisions
  end

  def quota_find_provision_by_owner(options)
    email = get_option(:owner_email).to_s.strip
    sched_type = get_option(:schedule_type).to_s.strip
    options[:scheduled_time] = sched_type == 'schedule' ? get_option(:schedule_time) : nil
    quota_find_provisions(options).delete_if { |p| email.casecmp(p.get_option(:owner_email).to_s.strip) != 0 }
  end

  def quota_find_provision_by_group(options)
    prov_requests = []
    prov_owner = get_owner
    unless prov_owner.nil?
      group = prov_owner.ldap_group
      sched_type = get_option(:schedule_type).to_s.strip
      options[:scheduled_time] = sched_type == 'schedule' ? get_option(:schedule_time) : nil
      prov_requests = quota_find_provisions(options).delete_if do |p|
        prov_req_owner = p.get_owner
        prov_req_owner.nil? ? true : group.casecmp(prov_req_owner.ldap_group) != 0
      end
    end
    prov_requests
  end

  def quota_find_prov_requests(_options)
    today_time_range = quota_get_time_range
    requests = MiqRequest.where("type = ? and approval_state != ? and (created_on >= ? and created_on < ?)",
                                MiqProvisionRequest.name, 'denied', *today_time_range)
    # Make sure we skip the current MiqProvisionRequest in the calculation.
    skip_id = self.class.name == "MiqProvisionRequest" ? id : miq_provision_request.id
    requests.collect { |request| request unless request.id == skip_id }.compact
  end

  def quota_find_prov_request_by_owner(options)
    email = get_option(:owner_email).to_s.strip
    quota_find_prov_requests(options).delete_if { |p| email.casecmp(p.get_option(:owner_email).to_s.strip) != 0 }
  end

  def quota_find_prov_request_by_group(options)
    prov_requests = []
    prov_owner = get_owner
    unless prov_owner.nil?
      group = prov_owner.ldap_group
      prov_requests = quota_find_prov_requests(options).delete_if do |p|
        prov_req_owner = p.get_owner
        prov_req_owner.nil? ? true : group.casecmp(prov_req_owner.ldap_group) != 0
      end
    end
    prov_requests
  end

  def quota_find_active_prov_request_by_owner(options)
    quota_find_active_prov_request(options).select { |p| request_owner_email(self).casecmp(p.request_owner_email(p)).zero? }
  end

  def request_owner_email(request)
    service_request?(request) ? request.requester.email : request.get_option(:owner_email)
  end

  def service_request?(request)
    request.kind_of?(ServiceTemplateProvisionRequest)
  end

  def quota_find_active_prov_request_by_group(options)
    prov_request_group = miq_request.options[:requester_group]
    quota_find_active_prov_request(options).select do |r|
      prov_request_group == r.options[:requester_group]
    end
  end

  def quota_find_active_prov_request_by_tenant(options)
    quota_find_active_prov_request(options).where(:tenant => miq_request.tenant)
  end

  def quota_find_active_prov_request(_options)
    MiqRequest.where(
      :approval_state => 'approved',
      :type           => %w(MiqProvisionRequest ServiceTemplateProvisionRequest),
      :request_state  => %w(active queued pending),
      :status         => 'Ok',
      :process        => true
    ).where.not(:id => id)
              .where(%{source_type IS NULL OR
       (source_type = 'VmOrTemplate' AND source_id IN (SELECT id FROM vms)) OR
       (source_type = 'ServiceTemplate' AND source_id IN (SELECT id FROM service_templates))
     })
  end

  def vm_quota_values(pr, result)
    num_vms_for_request = number_of_vms(pr)
    return if num_vms_for_request.zero?
    flavor_obj = flavor(pr)
    result[:count] += num_vms_for_request
    result[:memory] += memory(pr, cloud?(pr), vendor(pr), flavor_obj) * num_vms_for_request
    result[:cpu] += number_of_cpus(pr, cloud?(pr), flavor_obj) * num_vms_for_request
    result[:storage] += storage(pr, cloud?(pr), vendor(pr), flavor_obj) * num_vms_for_request
    result[:ids] << pr.id

    pr.miq_request_tasks.each do |p|
      next unless p.state == 'Active'
      host_id, storage_id = p.get_option(:dest_host).to_i, p.get_option(:dest_storage).to_i
      active = result[:active]
      active[:memory_by_host_id][host_id] += memory(p, cloud?(pr), vendor(pr), flavor_obj)
      active[:cpu_by_host_id][host_id] += number_of_cpus(p, cloud?(pr), flavor_obj)
      active[:storage_by_id][storage_id] += storage(p, cloud?(pr), vendor(pr), flavor_obj)
      active[:vms_by_storage_id][storage_id] << p.id
      active[:ids] << p.id
    end
  end

  def service_quota_values(request, result)
    return unless request.service_template
    request.service_template.service_resources.each do |sr|
      if request.service_template.service_type == ServiceTemplate::SERVICE_TYPE_COMPOSITE
        bundle_quota_values(sr, result)
      else
        next if request.service_template.prov_type.starts_with?("generic")
        vm_quota_values(sr.resource, result)
      end
    end
  end

  def bundle_quota_values(service_resource, result)
    return if service_resource.resource.prov_type.starts_with?('generic')
    service_resource.resource.service_resources.each do |sr|
      vm_quota_values(sr.resource, result)
    end
  end

  def quota_provision_stats(prov_method, options)
    result = {:count => 0, :memory => 0, :cpu => 0, :storage => 0, :ids => [], :class_name => "MiqProvisionRequest",
              :active => {
                :class_name => "MiqProvision", :ids => [], :storage_by_id => Hash.new { |k, v| k[v] = 0 },
                :memory_by_host_id => Hash.new { |k, v| k[v] = 0 },  :cpu_by_host_id => Hash.new { |k, v| k[v] = 0 },
                :vms_by_storage_id => Hash.new { |k, v| k[v] = [] }
              }
             }

    send(prov_method, options).each do |pr|
      service_request?(pr) ? service_quota_values(pr, result) : vm_quota_values(pr, result)
    end
    result
  end

  def number_of_vms(request)
    num_vms_for_request = request.get_option(:number_of_vms).to_i
    if options[:nil_vm_id_only] == true && request.miq_request_tasks.length == num_vms_for_request
      num_vms_for_request = request.miq_request_tasks.where(:destination_id => nil).where.not(:state => 'finished').count
    end
    num_vms_for_request
  end

  def cloud?(request)
    request.source.try(:cloud) || false
  end

  def vendor(request)
    request.source.try(:vendor)
  end

  def flavor(request)
    Flavor.find(request.get_option(:instance_type)) if cloud?(request)
  end

  def number_of_cpus(prov, cloud, flavor_obj)
    return flavor_obj.try(:cpus) if cloud
    request = prov.kind_of?(MiqRequest) ? prov : prov.miq_request
    num_cpus = request.get_option(:number_of_sockets).to_i * request.get_option(:cores_per_socket).to_i
    num_cpus.zero? ? request.get_option(:number_of_cpus).to_i : num_cpus
  end

  def storage(prov, cloud, vendor, flavor_obj = nil)
    if cloud
      if vendor == 'google'
        return prov.get_option(:boot_disk_size).to_i.gigabytes
      end
      return nil unless flavor_obj
      flavor_obj.root_disk_size.to_i + flavor_obj.ephemeral_disk_size.to_i + flavor_obj.swap_disk_size.to_i
    else
      prov.kind_of?(MiqRequest) ? prov.vm_template.provisioned_storage : prov.miq_request.vm_template.provisioned_storage
    end
  end

  def memory(prov, cloud, vendor, flavor_obj = nil)
    return flavor_obj.try(:memory) if cloud
    request = prov.kind_of?(MiqRequest) ? prov : prov.miq_request
    memory = request.get_option(:vm_memory).to_i
    %w(amazon openstack google).include?(vendor) ? memory : memory.megabytes
  end
end
