require 'ancestry'
class OrchestrationStack < ApplicationRecord
  require_nested :Status

  include NewWithTypeStiMixin
  include AsyncDeleteMixin
  include ProcessTasksMixin
  include_concern 'RetirementManagement'
  include TenantIdentityMixin

  acts_as_miq_taggable

  has_ancestry

  belongs_to :ext_management_system, :foreign_key => :ems_id

  has_many   :authentication_orchestration_stacks
  has_many   :authentications, :through => :authentication_orchestration_stacks
  has_many   :parameters, :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackParameter"
  has_many   :outputs,    :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackOutput"
  has_many   :resources,  :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackResource"

  has_many   :authentication_orchestration_stacks, :dependent => :destroy
  has_many   :authentications, :through => :authentication_orchestration_stacks

  has_many   :direct_vms,             :class_name => "ManageIQ::Providers::CloudManager::Vm"
  has_many   :direct_security_groups, :class_name => "SecurityGroup"
  has_many   :direct_cloud_networks,  :class_name => "CloudNetwork"
  has_many   :service_resources, :as => :resource
  has_many   :direct_services, :through => :service_resources, :source => :service

  virtual_has_one  :direct_service,       :class_name => 'Service'
  virtual_has_one  :service,              :class_name => 'Service'

  virtual_has_many :vms, :class_name => "ManageIQ::Providers::CloudManager::Vm"
  virtual_has_many :security_groups
  virtual_has_many :cloud_networks
  virtual_has_many :orchestration_stacks

  virtual_total :total_vms, :vms
  virtual_total :total_security_groups, :security_groups
  virtual_total :total_cloud_networks, :cloud_networks

  virtual_column :stdout, :type => :string

  alias_method :orchestration_stack_parameters, :parameters
  alias_method :orchestration_stack_outputs,    :outputs
  alias_method :orchestration_stack_resources,  :resources

  def orchestration_stacks
    children
  end

  def direct_service
    direct_services.first || (root.direct_services.first if root != self)
  end

  def service
    direct_service.try(:root_service) || (root.direct_service.try(:root_service) if root != self)
  end

  def indirect_vms
    MiqPreloader.preload_and_map(children, :direct_vms)
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
    MiqPreloader.preload_and_map(subtree, direct_attrs)
  end

  def stdout(format = nil)
    format.nil? ? try(:raw_stdout) : try(:raw_stdout, format)
  end

  private :directs_and_indirects

  def self.create_stack(orchestration_manager, stack_name, template, options = {})
    raw_create_stack(orchestration_manager, stack_name, template, options)
  end

  def self.raw_create_stack(_orchestration_manager, _stack_name, _template, _options = {})
    raise NotImplementedError, _("raw_create_stack must be implemented in a subclass")
  end

  def raw_update_stack(_template, _options = {})
    raise NotImplementedError, _("raw_update_stack must be implemented in a subclass")
  end

  def update_stack_queue(userid, template, options = {})
    task_opts = {
      :action => "updating Orchestration Stack for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_stack',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [template, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_stack(template, options = {})
    raw_update_stack(template, options)
  end

  def raw_delete_stack
    raise NotImplementedError, _("raw_delete_stack must be implemented in a subclass")
  end

  def delete_stack
    raw_delete_stack
  end

  def raw_status
    raise NotImplementedError, _("raw_status must be implemented in a subclass")
  end

  def raw_exists?
    rstatus = raw_status
    rstatus && !rstatus.deleted?
  rescue MiqException::MiqOrchestrationStackNotExistError
    false
  end
end
