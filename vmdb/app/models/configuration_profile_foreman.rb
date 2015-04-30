class ConfigurationProfileForeman < ConfigurationProfile
  belongs_to :parent, :class_name => 'ConfigurationProfileForeman'
  belongs_to :direct_operating_system_flavor,
             :class_name  => 'OperatingSystemFlavor'
  belongs_to :direct_customization_script_ptable,
             :class_name  => 'CustomizationScriptPtable'
  belongs_to :direct_customization_script_medium,
             :class_name  => 'CustomizationScriptMedium'

  has_and_belongs_to_many :direct_configuration_tags,
                          :join_table  => 'direct_configuration_profiles_configuration_tags',
                          :class_name  => 'ConfigurationTag',
                          :foreign_key => :configuration_profile_id

  delegate :name, :to => :configuration_architecture,    :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_compute_profile, :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_domain,          :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_environment,     :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_realm,           :prefix => true, :allow_nil => true
  delegate :name, :to => :operating_system_flavor,       :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_medium,   :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_ptable,   :prefix => true, :allow_nil => true

end
