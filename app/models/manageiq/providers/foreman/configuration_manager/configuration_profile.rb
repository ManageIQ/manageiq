class ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile < ::ConfigurationProfile
  belongs_to :parent, :class_name => 'ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile'
  belongs_to :direct_operating_system_flavor,
             :class_name  => 'OperatingSystemFlavor'
  belongs_to :direct_customization_script_ptable,
             :class_name  => 'CustomizationScriptPtable'
  belongs_to :direct_customization_script_medium,
             :class_name  => 'CustomizationScriptMedium'

  has_many :children,
           :class_name  => 'ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile',
           :foreign_key => :parent_id

  has_and_belongs_to_many :direct_configuration_tags,
                          :join_table  => 'direct_configuration_profiles_configuration_tags',
                          :class_name  => 'ConfigurationTag',
                          :foreign_key => :configuration_profile_id

  def configuration_profile
    self
  end
end
