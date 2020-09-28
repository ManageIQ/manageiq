class ConfigurationProfile < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin

  acts_as_miq_taggable
  belongs_to :manager, :class_name => 'ExtManagementSystem'
  belongs_to :parent, :class_name => 'ConfigurationProfile'
  belongs_to :customization_script_ptable
  belongs_to :customization_script_medium
  belongs_to :operating_system_flavor

  has_many :configured_systems

  has_and_belongs_to_many :configuration_locations, :join_table => :configuration_locations_configuration_profiles
  has_and_belongs_to_many :configuration_organizations, :join_table => :configuration_organizations_configuration_profiles
  has_and_belongs_to_many :configuration_tags, :join_table => :configuration_profiles_configuration_tags

  delegate :name, :to => :configuration_architecture,    :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_compute_profile, :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_domain,          :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_environment,     :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_realm,           :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_medium,   :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_ptable,   :prefix => true, :allow_nil => true
  delegate :name, :to => :operating_system_flavor,       :prefix => true, :allow_nil => true

  delegate :my_zone, :provider, :zone, :to => :manager

  virtual_has_one :configuration_architecture,  :class_name => 'ConfigurationArchitecture', :uses => :configuration_tags
  virtual_has_one :configuration_compute_profile, :class_name => 'ConfigurationProfile',    :uses => :configuration_tags
  virtual_has_one :configuration_domain,          :class_name => 'ConfigurationDomain',     :uses => :configuration_tags
  virtual_has_one :configuration_environment,    :class_name => 'ConfigurationEnvironment', :uses => :configuration_tags
  virtual_has_one :configuration_realm,           :class_name => 'ConfigurationRealm',      :uses => :configuration_tags

  virtual_column  :total_configured_systems,           :type => :integer
  virtual_column  :my_zone,                            :type => :string
  virtual_column  :configuration_architecture_name,    :type => :string
  virtual_column  :configuration_compute_profile_name, :type => :string
  virtual_column  :configuration_domain_name,          :type => :string
  virtual_column  :configuration_environment_name,     :type => :string
  virtual_column  :configuration_realm_name,           :type => :string
  virtual_column  :customization_script_medium_name,   :type => :string
  virtual_column  :customization_script_ptable_name,   :type => :string
  virtual_column  :operating_system_flavor_name,       :type => :string

  scope :with_manager, ->(manager_id) { where(:manager_id => manager_id) }

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
    @tag_hash ||= configuration_tags.index_by(&:class)
  end

  alias_method :configuration_manager, :manager

  def total_configured_systems
    Rbac.filtered(configured_systems).count
  end

  def image_name
    "configuration_profile"
  end
end
