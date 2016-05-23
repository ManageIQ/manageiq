class OrchestrationTemplateVnfd < OrchestrationTemplate
  def parameter_groups
    []
  end

  def parameters
    []
  end

  def self.eligible_manager_types
    [ManageIQ::Providers::Openstack::CloudManager]
  end

  # return the parsing error message if not valid YAML; otherwise nil
  def validate_format
    YAML.parse(content) && nil if content
  rescue Psych::SyntaxError => err
    err.message
  end
end
