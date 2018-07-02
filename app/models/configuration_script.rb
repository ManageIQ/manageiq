class ConfigurationScript < ConfigurationScriptBase
  def self.base_model
    ConfigurationScript
  end
  belongs_to :manager, :class_name => "ExtManagementSystem", :inverse_of => :configuration_scripts_and_workflows
end
