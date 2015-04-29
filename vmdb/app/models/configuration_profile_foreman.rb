class ConfigurationProfileForeman < ConfigurationProfile
  belongs_to :parent, :class_name => 'ConfigurationProfileForeman'

  belongs_to :direct_operating_system_flavor,
             :class_name  => 'OperatingSystemFlavor'

  belongs_to :direct_customization_script_ptable,
             :class_name  => 'CustomizationScriptPtable'

  belongs_to :direct_customization_script_medium,
             :class_name  => 'CustomizationScriptMedium'

  has_and_belongs_to_many :direct_configuration_tags,
                          :join_table  => 'configuration_profiles_configuration_tags',
                          :class_name  => 'ConfigurationTag',
                          :foreign_key => :configuration_profile_id

  # derived values (to be used by ui)
  virtual_has_many :configuration_tags,  :class_name => 'ConfigurationTag'

  delegate :name, :to => :configuration_architecture,    :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_compute_profile, :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_domain,          :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_environment,     :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_realm,           :prefix => true, :allow_nil => true
  delegate :name, :to => :operating_system_flavor,       :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_medium,   :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_ptable,   :prefix => true, :allow_nil => true

  def configuration_tags
    tag_hash.values
  end

  def configuration_architecture
    tag_hash[ConfigurationArchitecture]
  end

  def configuration_compute_profile
    tag_hash[ConfigurationComputeProfile]
  end

  def configuration_domain
    tag_hash[ConfigurationDomain]
  end

  def configuration_environment
    tag_hash[ConfigurationEnvironment]
  end

  def configuration_realm
    tag_hash[ConfigurationRealm]
  end

  def tag_hash
    @tag_hash ||= begin
      tag_hash = direct_configuration_tags.index_by(&:class)
      parent ? tag_hash.reverse_merge(parent.tag_hash) : tag_hash
    end
  end
end
