class ManageIQ::Providers::Redhat::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'Reconfigure'
  include_concern 'ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared'

  supports :migrate do
    if blank? || orphaned? || archived?
      unsupported_reason_add(:migrate, "Migrate operation in not supported.")
    elsif !ext_management_system.supports_migrate?
      unsupported_reason_add(:migrate, 'RHV API version does not support migrate')
    end
  end

  supports :reconfigure_disks do
    if storage.blank?
      unsupported_reason_add(:reconfigure_disks, _('storage is missing'))
    elsif ext_management_system.blank?
      unsupported_reason_add(:reconfigure_disks, _('The virtual machine is not associated with a provider'))
    elsif !ext_management_system.supports_reconfigure_disks?
      unsupported_reason_add(:reconfigure_disks, _('The provider does not support reconfigure disks'))
    end
  end

  supports_not :publish

  POWER_STATES = {
    'up'        => 'on',
    'down'      => 'off',
    'suspended' => 'suspended',
  }.freeze

  def provider_object(connection = nil)
    ovirt_services_class = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Builder
                           .build_from_ems_or_connection(:ems => ext_management_system, :connection => connection)
    ovirt_services_class.new(:ems => ext_management_system).get_vm_proxy(self, connection)
  end

  def scan_via_ems?
    true
  end

  def parent_cluster
    rp = parent_resource_pool
    rp && rp.detect_ancestor(:of_type => "EmsCluster").first
  end
  alias owning_cluster parent_cluster
  alias ems_cluster parent_cluster

  def disconnect_storage(_s = nil)
    unless active?
      return
    end
    vm_disks = collect_disks

    if vm_disks.blank?
      storage = nil
    else
      vm_storages = ([storage] + storages).compact.uniq
      storage = vm_storages.select { |store| !vm_disks.include?(store.ems_ref) }
    end

    super(storage)
  end

  def collect_disks
    return [] if hardware.nil?
    disks = hardware.disks.map { |disk| "#{disk.storage.ems_ref}/disks/#{disk.filename}" }
    ext_management_system.ovirt_services.collect_disks_by_hrefs(disks)
  end

  def disconnect_inv
    disconnect_storage

    super
  end

  #
  # UI Button Validation Methods
  #

  def has_required_host?
    true
  end

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || super
  end
end
