module MiqProvision::OptionsHelper
  def dest_name
    get_option(:vm_target_name)
  end

  def dest_hostname
    get_option(:vm_target_hostname)
  end

  def dest_cluster
    @dest_cluster ||= EmsCluster.find_by(:id => get_option(:dest_cluster))
  end

  def dest_host
    @dest_host ||= Host.find_by(:id => get_option(:dest_host))
  end

  def dest_datastore
    @dest_datastore ||= Storage.find_by(:id => get_option(:dest_storage))
  end

  def create_template?
    get_option(:request_type) == :clone_to_template
  end

  def get_source
    source_id = get_option(:src_vm_id)
    source = VmOrTemplate.find_by(:id => source_id)
    if source.nil?
      raise MiqException::MiqProvisionError,
            _("Unable to find source Template/Vm with id [%{number}]") % {:number => source_id}
    end
    ems = source.ext_management_system
    if ems.nil?
      raise MiqException::MiqProvisionError,
            _("%{class_name} [%{name}] is not attached to a Management System") % {:class_name => source.class.name,
                                                                                   :name       => source.name}
    end
    unless ems.supports_provisioning?
      raise MiqException::MiqProvisionError,
            _("%{class_name} [%{name}] is attached to <%{ems_class_name}: %{ems_name}> that does not support Provisioning") %
              {:class_name     => source.class.name,
               :name           => source.name,
               :ems_class_name => ems.class.name,
               :ems_name       => ems.name}
    end
    if ems.missing_credentials?
      raise MiqException::MiqProvisionError,
            _("%{class_name} [%{name}] is attached to <%{ems_class_name}: %{ems_name}> with missing credentials") %
              {:class_name     => source.class.name,
               :name           => source.name,
               :ems_class_name => ems.class.name,
               :ems_name       => ems.name}
    end
    source
  end

  def get_hostname(dest_vm_name)
    name_key = (source.platform == 'windows') ? :sysprep_computer_name : :linux_host_name
    computer_name = (get_option(:number_of_vms) > 1) ? nil : get_option(name_key).to_s.strip
    computer_name = dest_vm_name if computer_name.blank?
    hostname_cleanup(computer_name)
  end

  def set_static_ip_address(pass = nil)
    pass ||= get_option(:pass).to_i
    pass -= 1
    return if pass <= 0
    ip_address = get_option(:ip_addr)
    return unless ip_address.to_s.ipv4?
    ip_seg = ip_address.split('.')
    ip_seg[-1] = ip_seg[-1].to_i + pass
    options[:ip_addr] = ip_seg.join('.')
  end

  def set_dns_domain
    # If the DNS Domain is not set use the first item from the DNS Suffix list
    value = get_option(:dns_domain)
    if value.blank?
      value = get_option(:dns_suffixes).to_s.split(',').first
      options[:dns_domain] = value.try(:strip)
    end
  end
end
