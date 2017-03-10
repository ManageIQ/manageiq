module ServiceConfigurationMixin
  extend ActiveSupport::Concern

  included do
    has_many :configuration_scripts, :through => :service_resources, :source => :resource, :source_type => 'ConfigurationScriptBase'
    private :configuration_scripts, :configuration_scripts=
  end

  def configuration_script
    configuration_scripts.take
  end

  def configuration_script=(script)
    self.configuration_scripts = [script].compact
  end

  def configuration_manager
    configuration_script.try(:manager)
  end
end
