class ManageIQ::Providers::CloudManager::OrchestrationStack < ::OrchestrationStack
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :orchestration_template
  belongs_to :cloud_tenant

  has_many   :direct_vms,             :class_name => "ManageIQ::Providers::CloudManager::Vm"
  has_many   :direct_security_groups, :class_name => "SecurityGroup"
  has_many   :direct_cloud_networks,  :class_name => "CloudNetwork"

  virtual_has_many :vms, :class_name => "ManageIQ::Providers::CloudManager::Vm"
  virtual_has_many :security_groups
  virtual_has_many :cloud_networks

  virtual_column :total_vms,             :type => :integer
  virtual_column :total_security_groups, :type => :integer
  virtual_column :total_cloud_networks,  :type => :integer

  def total_vms
    vms.size
  end

  def total_security_groups
    security_groups.size
  end

  def total_cloud_networks
    cloud_networks.size
  end

  def vms
    directs_and_indirects(:direct_vms)
  end

  def security_groups
    directs_and_indirects(:direct_security_groups)
  end

  def cloud_networks
    directs_and_indirects(:direct_cloud_networks)
  end

  def self.create_stack(orchestration_manager, stack_name, template, options = {})
    klass = orchestration_manager.class::OrchestrationStack
    ems_ref = klass.raw_create_stack(orchestration_manager, stack_name, template, options)
    tenant = CloudTenant.find_by(:name => options[:tenant_name], :ems_id => orchestration_manager.id)

    klass.create(:name                   => stack_name,
                 :ems_ref                => ems_ref,
                 :status                 => 'CREATE_IN_PROGRESS',
                 :resource_group         => options[:resource_group],
                 :ext_management_system  => orchestration_manager,
                 :cloud_tenant           => tenant,
                 :orchestration_template => template)
  end
end
