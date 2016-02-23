require 'ancestry'
class OrchestrationStack < ApplicationRecord
  require_nested :Status

  include NewWithTypeStiMixin
  include ReportableMixin
  include AsyncDeleteMixin
  include ProcessTasksMixin
  include_concern 'RetirementManagement'

  acts_as_miq_taggable

  has_ancestry

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :orchestration_template
  belongs_to :cloud_tenant

  has_many   :direct_vms,             :class_name => "ManageIQ::Providers::CloudManager::Vm"
  has_many   :direct_security_groups, :class_name => "SecurityGroup"
  has_many   :direct_cloud_networks,  :class_name => "CloudNetwork"

  virtual_has_many :vms, :class_name => "ManageIQ::Providers::CloudManager::Vm"
  virtual_has_many :security_groups
  virtual_has_many :cloud_networks

  has_many   :parameters, :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackParameter"
  has_many   :outputs,    :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackOutput"
  has_many   :resources,  :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackResource"

  alias_method :orchestration_stack_parameters, :parameters
  alias_method :orchestration_stack_outputs,    :outputs
  alias_method :orchestration_stack_resources,  :resources

  virtual_column :total_vms,             :type => :integer
  virtual_column :total_security_groups, :type => :integer
  virtual_column :total_cloud_networks,  :type => :integer

  def tenant_identity
    if ext_management_system
      ext_management_system.tenant_identity
    else
      User.super_admin.tap { |u| u.current_group = Tenant.root_tenant.default_miq_group }
    end
  end

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

  def directs_and_indirects(direct_attrs)
    return send(direct_attrs) if descendants.blank?

    indirects = descendants.inject([]) { |arr, child| arr << child.send(direct_attrs) }
    (indirects << send(direct_attrs)).flatten
  end
  private :directs_and_indirects

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

  def self.raw_create_stack(_orchestration_manager, _stack_name, _template, _options = {})
    raise NotImplementedError, "raw_create_stack must be implemented in a subclass"
  end

  def raw_update_stack(_template, _options = {})
    raise NotImplementedError, "raw_update_stack must be implemented in a subclass"
  end

  def update_stack(template, options = {})
    raw_update_stack(template, options)
  end

  def raw_delete_stack
    raise NotImplementedError, "raw_delete_stack must be implemented in a subclass"
  end

  def delete_stack
    raw_delete_stack
  end

  def raw_status
    raise NotImplementedError, "raw_status must be implemented in a subclass"
  end

  def raw_exists?
    rstatus = raw_status
    rstatus && !rstatus.deleted?
  rescue MiqException::MiqOrchestrationStackNotExistError
    false
  end
end
