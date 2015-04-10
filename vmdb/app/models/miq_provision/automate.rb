module MiqProvision::Automate
  extend ActiveSupport::Concern

  module ClassMethods
    def get_domain_details(domain, with_password = false, user = nil)
      log_prefix = "MIQ(#{self.class.name}.get_domain_details)"
      $log.info "#{log_prefix} << domain=<#{domain}> with_password=#{with_password} user=<#{user}>"
      if domain.nil?
        $log.error "#{log_prefix} Domain Not specified"
        return nil
      end

      attrs = {'request' => 'UI_PROVISION_INFO', 'message' => 'get_domains'}
      attrs[MiqAeEngine.create_automation_attribute_key(user)] = MiqAeEngine.create_automation_attribute_value(user) unless user.nil?
      uri = MiqAeEngine.create_automation_object("REQUEST", attrs)
      ws  = MiqAeEngine.resolve_automation_object(uri)

      if ws.root.nil?
        $log.warn "#{log_prefix} - Automate Failed (workspace empty)"
        return nil
      end

      domains = ws.root['domains']

      domains.each_with_index do |d, _i|
        next unless domain.casecmp(d[:name]) == 0
        password = d.delete(:bind_password)
        d[:bind_password] = MiqAePassword.decrypt_if_password(password) if with_password == true
        return d
      end if domains.kind_of?(Array)

      $log.warn "#{log_prefix} - No Domains matched in Automate Results: #{ws.to_expanded_xml}"
      nil
    end
  end

  def get_placement_via_automate
    attrs = {
      'request' => 'UI_PROVISION_INFO',
      'message' => 'get_placement'
    }
    attrs[MiqAeEngine.create_automation_attribute_key(get_user)] = MiqAeEngine.create_automation_attribute_value(get_user) unless get_user.nil?
    uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => self)
    ws  = MiqAeEngine.resolve_automation_object(uri)
    reload

    {
      :host    => MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["host"]),
      :storage => MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["storage"]),
      :cluster => MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["cluster"]),
    }
  end

  def get_most_suitable_availability_zone
    attrs = {
      'request' => 'UI_PROVISION_INFO',
      'message' => 'get_availability_zone'
    }
    attrs[MiqAeEngine.create_automation_attribute_key(get_user)] = MiqAeEngine.create_automation_attribute_value(get_user) unless get_user.nil?
    uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => self)
    ws  = MiqAeEngine.resolve_automation_object(uri)
    reload
    MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["availability_zone"])
  end

  def get_most_suitable_host_and_storage
    attrs = {
      'request' => 'UI_PROVISION_INFO',
      'message' => 'get_host_and_storage'
    }
    attrs[MiqAeEngine.create_automation_attribute_key(get_user)] = MiqAeEngine.create_automation_attribute_value(get_user) unless get_user.nil?
    uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => self)
    ws  = MiqAeEngine.resolve_automation_object(uri)
    reload
    host      = MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["host"])
    datastore = MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["storage"])
    return host, datastore
  end

  def get_most_suitable_cluster
    attrs = {
      'request' => 'UI_PROVISION_INFO',
      'message' => 'get_cluster'
    }
    attrs[MiqAeEngine.create_automation_attribute_key(get_user)] = MiqAeEngine.create_automation_attribute_value(get_user) unless get_user.nil?
    uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => self)
    ws  = MiqAeEngine.resolve_automation_object(uri)
    reload
    MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["cluster"])
  end

  def get_most_suitable_host
    attrs = {
      'request' => 'UI_PROVISION_INFO',
      'message' => 'get_host'
    }
    attrs[MiqAeEngine.create_automation_attribute_key(get_user)] = MiqAeEngine.create_automation_attribute_value(get_user) unless get_user.nil?
    uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => self)
    ws  = MiqAeEngine.resolve_automation_object(uri)
    reload
    MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["host"])
  end

  def get_network_scope
    network = get_network_details
    network.kind_of?(Hash) ? network[:scope] : nil
  end

  def get_network_details
    log_prefix = "MIQ(#{self.class.name}.get_network_details)"

    related_vm             = vm || source
    related_vm_description = (related_vm == vm) ? "VM" : "Template"

    if related_vm.nil?
      $log.error "#{log_prefix} No VM or Template Found for Provision Object"
      return nil
    end

    if related_vm.ext_management_system.nil?
      $log.error "#{log_prefix} No EMS Found for #{related_vm_description} of Provision Object"
      return nil
    end

    vc_id = related_vm.ext_management_system.id
    unless vc_id.kind_of?(Fixnum)
      $log.error "#{log_prefix} Invalid EMS ID <#{vc_id.inspect}> for #{related_vm_description} of Provision Object"
      return nil
    end

    vlan_id, vlan_name = options[:vlan]
    unless vlan_name.kind_of?(String)
      $log.error "#{log_prefix} VLAN Name <#{vlan_name.inspect}> is missing or invalid"
      return nil
    end

    $log.info "#{log_prefix} << vlan_name=<#{vlan_name}> vlan_id=#{vlan_id} vc_id=<#{vc_id}> user=<#{get_user}>"

    attrs = {
      'request' => 'UI_PROVISION_INFO',
      'message' => 'get_networks'
    }
    attrs[MiqAeEngine.create_automation_attribute_key(get_user)] = MiqAeEngine.create_automation_attribute_value(get_user) unless get_user.nil?
    uri = MiqAeEngine.create_automation_object("REQUEST", attrs)
    ws  = MiqAeEngine.resolve_automation_object(uri)

    if ws.root.nil?
      $log.warn "#{log_prefix} - Automate Failed (workspace empty)"
      return nil
    end

    networks = ws.root("networks")

    networks.each do |network|
      next unless network.kind_of?(Hash)
      next unless network[:vc_id] == vc_id
      next unless vlan_name.casecmp(network[:vlan]) == 0

      # Remove passwords
      network[:dhcp_servers].each do |dhcp|
        domain = dhcp[:domain]
        domain.delete(:bind_password) if domain.kind_of?(Hash)
      end if network[:dhcp_servers].kind_of?(Array)

      return network
    end if networks.kind_of?(Array)

    $log.warn "#{log_prefix} - No Network matched in Automate Results: #{ws.to_expanded_xml}"
    nil
  end

  def get_domain
    return options[:linux_domain_name]         unless options[:linux_domain_name].nil?
    return options[:sysprep_domain_name].first if     options[:sysprep_domain_name].kind_of?(Array)
    nil
  end

  def do_pre_provision
    log_header = "MIQ(#{self.class.name}.do_pre_provision)"

    event_name = 'vm_provision_preprocessing'
    ws = call_automate_event(event_name, false)
    reload
    if ws.nil?
      update_and_notify_parent(:state => "finished", :status => "Error", :message => "Automation Error in processing Event #{event_name}")
      return false
    end

    ae_result  = ws.root['ae_result']
    ae_message = ws.root['ae_message']

    unless ae_result.nil?
      return false if ae_result.casecmp("error").zero?

      if ae_result.casecmp("retry").zero?
        interval, unit = ae_message.split(".")
        interval = interval.to_i
        interval = interval * 60           if unit == "minute" || unit == "minutes"
        interval = interval * 60 * 60      if unit == "hour"   || unit == "hours"
        interval = interval * 60 * 60 * 24 if unit == "day"    || unit == "days"

        MiqQueue.put(
          :class_name  => self.class.name,
          :instance_id => id,
          :method_name => "execute",
          :zone        => my_zone,
          :role        => my_role,
          :task_id     => my_task_id,
          :msg_timeout => MiqProvision::CLONE_SYNCHRONOUS ? MiqProvision::CLONE_TIME_LIMIT : MiqQueue::TIMEOUT,
          :deliver_on  => Time.now.utc + interval
        )
        message = "Request [#{ae_message}] has been re-queued for processing in #{interval} seconds"
        $log.info("#{log_header} #{message}")
        update_and_notify_parent(:state => "queued", :status => "Ok", :message => message)
        return false
      end
    end

    true
  end
end
