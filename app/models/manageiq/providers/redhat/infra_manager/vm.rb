class ManageIQ::Providers::Redhat::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'Reconfigure'
  include_concern 'ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared'

  supports :migrate do
    unless ext_management_system.supports_migrate?
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

  POWER_STATES = {
    'up'        => 'on',
    'down'      => 'off',
    'suspended' => 'suspended',
  }.freeze

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.get_resource_by_ems_ref(ems_ref)
  end

  def scan_via_ems?
    true
  end

  def parent_cluster
    rp = parent_resource_pool
    rp && rp.detect_ancestor(:of_type => "EmsCluster").first
  end
  alias_method :owning_cluster, :parent_cluster
  alias_method :ems_cluster, :parent_cluster

  def disconnect_storage(_s = nil)
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
    disks = hardware.disks.map { |disk| "#{disk.storage.ems_ref}/disks/#{disk.filename}" }
    vm_disks = []

    ext_management_system.with_provider_connection do |rhevm|
      disks.each do |disk|
        begin
          vm_disks << Ovirt::Disk.find_by_href(rhevm, disk)
        rescue Ovirt::MissingResourceError
          nil
        end
      end
    end
    vm_disks
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

  def validate_publish
    validate_unsupported("Publish VM")
  end
end
