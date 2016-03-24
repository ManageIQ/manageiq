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

  belongs_to :ext_management_system, :foreign_key => :ems_id

  has_many   :parameters, :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackParameter"
  has_many   :outputs,    :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackOutput"
  has_many   :resources,  :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackResource"

  alias_method :orchestration_stack_parameters, :parameters
  alias_method :orchestration_stack_outputs,    :outputs
  alias_method :orchestration_stack_resources,  :resources

  def tenant_identity
    if ext_management_system
      ext_management_system.tenant_identity
    else
      User.super_admin.tap { |u| u.current_group = Tenant.root_tenant.default_miq_group }
    end
  end

  def directs_and_indirects(direct_attrs)
    MiqPreloader.preload_and_map(subtree, direct_attrs)
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
