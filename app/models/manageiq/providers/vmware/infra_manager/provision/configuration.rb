module ManageIQ::Providers::Vmware::InfraManager::Provision::Configuration
  extend ActiveSupport::Concern

  include_concern 'Container'
  include_concern 'Network'
  include_concern 'Disk'

  def reconfigure_hardware_on_destination?
    # Do we need to perform a post-clone hardware reconfigure on the new VM?
    [:cpu_limit, :memory_limit, :cpu_reserve, :memory_reserve].any? do |k|
      return false unless options.key?(k)
      destination.send(k) != options[k]
    end
  end
end
