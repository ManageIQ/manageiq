module ServiceOrchestrationMixin
  extend ActiveSupport::Concern

  included do
    has_many :orchestration_templates, :through => :service_resources, :source => :resource, :source_type => 'OrchestrationTemplate'
    has_many :orchestration_managers,  :through => :service_resources, :source => :resource, :source_type => 'ExtManagementSystem'
    private :orchestration_templates, :orchestration_templates=
    private :orchestration_managers, :orchestration_managers=
  end

  def orchestration_template
    orchestration_templates.take
  end

  def orchestration_template=(template)
    self.orchestration_templates = [template].compact
  end

  def orchestration_manager
    orchestration_managers.take
  end

  def orchestration_manager=(manager)
    self.orchestration_managers = [manager].compact
  end
end
