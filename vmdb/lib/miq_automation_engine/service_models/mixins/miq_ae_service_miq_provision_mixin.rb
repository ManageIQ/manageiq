module MiqAeServiceMiqProvisionMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def expose_eligible_resources(resource)
      method_name = "eligible_#{resource}"
      define_method(method_name) do
        ar_method do
          eligible_resources(resource.to_sym)
        end
      end
      association method_name

      define_method("set_#{resource.to_s.singularize}") do |rsc|
        ar_method do
          set_resource(rsc)
        end
      end
    end
  end

  def set_vm_notes(note)
    object_send(:set_vm_notes, note)
  end

  def register_automate_callback(callback_name, automate_uri)
    object_send(:register_automate_callback, callback_name, automate_uri)
  end

  def set_network_address_mode(mode)
    set_option(:addr_mode, ["dhcp",   "DHCP"])   if mode.downcase == "dhcp"
    set_option(:addr_mode, ["static", "Static"]) if mode.downcase == "static"
  end

  def check_quota(quota_type, options={})
    object_send(:check_quota, quota_type, options)
  end

  def eligible_resources(rsc_type)
    self.wrap_results(object_send(:eligible_resources, rsc_type))
  end

  def set_resource(rsc)
    object_send(:set_resource, rsc)
  end

  def set_nic_settings(idx, nic_hash, value=nil)
    object_send(:set_nic_settings, idx, nic_hash, value)
  end

  def set_network_adapter(idx, nic_hash, value=nil)
    object_send(:set_network_adapter, idx, nic_hash, value)
  end

  def set_dvs(portgroup, switch = portgroup)
    set_option(:vlan, ["dvs_#{portgroup}", "#{portgroup} (#{switch})"])
  end

  def set_vlan(vlan)
    set_option(:vlan, ["#{vlan}", "#{vlan}"])
  end

  def get_folder_paths
    object_send(:get_folder_paths)
  end

end
