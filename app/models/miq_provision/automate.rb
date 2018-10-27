module MiqProvision::Automate
  extend ActiveSupport::Concern

  module ClassMethods
    def vm_name_from_automate(prov_obj)
      prov_obj.save
      attrs = {'request' => 'UI_PROVISION_INFO', 'message' => 'get_vmname'}
      MiqAeEngine.set_automation_attributes_from_objects([prov_obj.get_user], attrs)
      MiqAeEngine.resolve_automation_object("REQUEST",
                                            prov_obj.get_user,
                                            attrs,
                                            :vmdb_object => prov_obj).root("vmname").tap do
        prov_obj.reload
      end
    end
  end

  def get_placement_via_automate
    attrs = automate_attributes('get_placement')
    ws = MiqAeEngine.resolve_automation_object("REQUEST", get_user, attrs, :vmdb_object => self)
    reload

    {
      :host    => MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["host"]),
      :storage => MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["storage"]),
      :cluster => MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["cluster"]),
    }
  end

  def get_most_suitable_availability_zone
    attrs = automate_attributes('get_availability_zone')
    ws = MiqAeEngine.resolve_automation_object("REQUEST", get_user, attrs, :vmdb_object => self)
    reload
    MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["availability_zone"])
  end

  def get_most_suitable_host_and_storage
    attrs = automate_attributes('get_host_and_storage')

    ws = MiqAeEngine.resolve_automation_object("REQUEST", get_user, attrs, :vmdb_object => self)
    reload
    host      = MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["host"])
    datastore = MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["storage"])
    return host, datastore
  end

  def get_most_suitable_cluster
    attrs = automate_attributes('get_cluster')
    ws = MiqAeEngine.resolve_automation_object("REQUEST", get_user, attrs, :vmdb_object => self)
    reload
    MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["cluster"])
  end

  def get_most_suitable_host
    attrs = automate_attributes('get_host')
    ws = MiqAeEngine.resolve_automation_object("REQUEST", get_user, attrs, :vmdb_object => self)
    reload
    MiqAeMethodService::MiqAeServiceConverter.svc2obj(ws.root["host"])
  end

  def get_network_scope
    network = get_network_details
    network[:scope] if network.kind_of?(Hash)
  end

  def get_network_details
    related_vm             = vm || source
    related_vm_description = (related_vm == vm) ? "VM" : "Template"

    if related_vm.nil?
      _log.error("No VM or Template Found for Provision Object")
      return nil
    end

    if related_vm.ext_management_system.nil?
      _log.error("No EMS Found for #{related_vm_description} of Provision Object")
      return nil
    end

    vc_id = related_vm.ext_management_system.id
    unless vc_id.kind_of?(Integer)
      _log.error("Invalid EMS ID <#{vc_id.inspect}> for #{related_vm_description} of Provision Object")
      return nil
    end

    vlan_id, vlan_name = options[:vlan]
    unless vlan_name.kind_of?(String)
      _log.error("VLAN Name <#{vlan_name.inspect}> is missing or invalid")
      return nil
    end

    _log.info("<< vlan_name=<#{vlan_name}> vlan_id=#{vlan_id} vc_id=<#{vc_id}> user=<#{get_user}>")

    attrs = automate_attributes('get_networks')
    ws = MiqAeEngine.resolve_automation_object("REQUEST", get_user, attrs)

    if ws.root.nil?
      _log.warn("- Automate Failed (workspace empty)")
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

    _log.warn("- No Network matched in Automate Results: #{ws.to_expanded_xml}")
    nil
  end

  def get_domain
    return options[:linux_domain_name]         unless options[:linux_domain_name].nil?
    return options[:sysprep_domain_name].first if     options[:sysprep_domain_name].kind_of?(Array)
    nil
  end

  def automate_attributes(message, objects = [get_user])
    MiqAeEngine.set_automation_attributes_from_objects(
      objects, 'request' => 'UI_PROVISION_INFO', 'message' => message)
  end
end
