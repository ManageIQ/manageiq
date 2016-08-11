class ManageIQ::Providers::Redhat::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'Reconfigure'
  include_concern 'ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared'

  supports_not :migrate, :reason => _("Migrate operation is not supported.")

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

  def self.create_from_event(event)
    data = event[:full_data]
    vm = data[:vm]
    cluster = data[:cluster]

    ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(vm[:href])
    cluster_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(cluster[:href])

    vm_data = [ems_ref.include?('/templates/'), ems_ref, vm[:id], event[:message].split(/\W/)[1]]
    vm_hash = ManageIQ::Providers::Redhat::InfraManager::RefreshParser.create_vm_hash(vm_data)

    old_cluster = EmsCluster.find_by(:ems_ref => cluster_ref)
    vm_hash[:ems_cluster_id] = old_cluster[:id]

    ems = ExtManagementSystem.find_by_id(event[:ems_id])
    new_vm = ems.vms_and_templates.build(vm_hash)
    new_vm.save!

    resource_pool = old_cluster.children.first
    resource_pool.add_vm(new_vm)
    resource_pool.save!

    new_vm
  end

  #
  # UI Button Validation Methods
  #

  def has_required_host?
    true
  end

  def cloneable?
    true
  end

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || super
  end

  def validate_publish
    validate_unsupported("Publish VM")
  end

  def validate_clone
    validate_unsupported("Clone")
  end
end
