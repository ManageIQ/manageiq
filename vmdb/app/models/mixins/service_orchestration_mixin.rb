module ServiceOrchestrationMixin
  extend ActiveSupport::Concern

  included do
    has_many :orchestration_templates, :through => :service_resources, :source => :resource, :source_type => 'OrchestrationTemplate'
    has_many :orchestration_managers,  :through => :service_resources, :source => :resource, :source_type => 'ExtManagementSystem'
    private :orchestration_templates, :orchestration_templates=
    private :orchestration_managers, :orchestration_managers=
  end

  def orchestration_template
    orchestration_templates.try(:at, 0)
  end

  def orchestration_template=(template)
    orchestration_templates.replace([template].compact)
  end

  def orchestration_manager
    orchestration_managers.try(:at, 0)
  end

  def orchestration_manager=(manager)
    orchestration_managers.replace([manager].compact)
  end
end
