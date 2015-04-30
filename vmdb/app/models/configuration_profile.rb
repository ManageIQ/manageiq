class ConfigurationProfile < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :configuration_manager
  belongs_to :parent, :class_name => 'ConfigurationProfile'
  belongs_to :customization_script_ptable
  belongs_to :customization_script_medium
  belongs_to :operating_system_flavor

  has_many :configured_systems

  has_and_belongs_to_many :configuration_locations, :join_table => :configuration_locations_configuration_profiles
  has_and_belongs_to_many :configuration_organizations, :join_table => :configuration_organizations_configuration_profiles
  has_and_belongs_to_many :configuration_tags

  virtual_has_one :configuration_architecture, :class_name => 'ConfigurationArchitecture', :uses => :configuration_tags

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

  alias_method :manager, :configuration_manager
end
