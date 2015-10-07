require 'ancestry'
class OrchestrationStack < ActiveRecord::Base
  require_dependency 'orchestration_stack/status'

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

  has_many   :vms, :class_name => "ManageIQ::Providers::CloudManager::Vm"
  has_many   :security_groups
  has_many   :cloud_networks
  has_many   :parameters, :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackParameter"
  has_many   :outputs,    :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackOutput"
  has_many   :resources,  :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackResource"

  alias_method :orchestration_stack_parameters, :parameters
  alias_method :orchestration_stack_outputs,    :outputs
  alias_method :orchestration_stack_resources,  :resources

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

  def self.create_stack(orchestration_manager, stack_name, template, options = {})
    klass = orchestration_manager.class::OrchestrationStack
    ems_ref = klass.raw_create_stack(orchestration_manager, stack_name, template, options)

    klass.create(:name                   => stack_name,
                 :ems_ref                => ems_ref,
                 :status                 => 'CREATE_IN_PROGRESS',
                 :ext_management_system  => orchestration_manager,
                 :orchestration_template => template)
  end

  def self.raw_create_stack(_orchestration_manager, _stack_name, _template, _options = {})
    raise NotImplementedError, "raw_create_stack must be implemented in a subclass"
  end

  def raw_update_stack(_options = {})
    raise NotImplementedError, "raw_update_stack must be implemented in a subclass"
  end

  def update_stack(options = {})
    raw_update_stack(options)
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
