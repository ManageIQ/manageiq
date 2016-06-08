module ManageIQ::Providers::Vmware::InfraManager::VmOrTemplateShared
  extend ActiveSupport::Concern
  include_concern 'RefreshOnScan'
  include_concern 'Scanning'

  POWER_STATES = {
    "poweredOn"  => "on",
    "poweredOff" => "off",
    "suspended"  => "suspended",
  }.freeze

  module ClassMethods
    def calculate_power_state(raw_power_state)
      POWER_STATES[raw_power_state] || super
    end
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    api_type = connection.about["apiType"]
    mor =
      case api_type
      when "VirtualCenter"
        # The ems_ref in the VMDB is from the vCenter perspective
        ems_ref
      when "HostAgent"
        # Since we are going directly to the host, it acts like a VC
        # Thus, there is only a single host in it
        # It has a MOR for itself, which is different from the vCenter MOR
        connection.hostSystemsByMor.keys.first
      else
        raise "Unknown connection API type '#{api_type}'"
      end

    connection.getVimVmByMor(mor)
  end

  def provider_object_release(handle)
    handle.release if handle rescue nil
  end
end
