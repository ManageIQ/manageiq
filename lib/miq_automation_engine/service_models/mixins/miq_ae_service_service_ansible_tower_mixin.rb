module MiqAeServiceServiceAnsibleTowerMixin
  extend ActiveSupport::Concern
  included do
    expose :job_template
    expose :configuration_manager
  end

  def job_template=(template)
    if template && !template.kind_of?(MiqAeMethodService::MiqAeServiceConfigurationScript)
      raise ArgumentError, "template must be a MiqAeServiceConfigurationScript or nil"
    end

    ar_method do
      @object.job_template = template ? ConfigurationScript.find_by(:id => template.id): nil
      @object.save
    end
  end

  def configuration_manager=(manager)
    if manager && !manager.kind_of?(MiqAeMethodService::MiqAeServiceExtManagementSystem)
      raise ArgumentError, "manager must be a MiqAeServiceExtManagementSystem or nil"
    end

    ar_method do
      @object.configuration_manager = manager ? ExtManagementSystem.where(:id => manager.id).first : nil
      @object.save
    end
  end
end
