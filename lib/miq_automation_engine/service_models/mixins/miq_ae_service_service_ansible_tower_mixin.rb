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
end
