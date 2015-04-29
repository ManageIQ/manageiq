class ConfiguredSystemForeman < ConfiguredSystem
  include ProviderObjectMixin

  belongs_to :configuration_profile, :class_name => 'ConfigurationProfileForeman'
  belongs_to :direct_operating_system_flavor,
             :class_name  => 'OperatingSystemFlavor'
  belongs_to :direct_customization_script_medium,
             :class_name => "CustomizationScriptMedium"
  belongs_to :direct_customization_script_ptable,
             :class_name => "CustomizationScriptPtable"

  has_and_belongs_to_many :direct_configuration_tags,
                          :join_table  => 'direct_configuration_tags_configured_systems',
                          :class_name  => 'ConfigurationTag',
                          :foreign_key => :configured_system_id

  def provider_object(connection = nil)
    (connection || connection_source.connect).host(manager_ref)
  end

  private

  def connection_source(options = {})
    options[:connection_source] || configuration_manager
  end
end
