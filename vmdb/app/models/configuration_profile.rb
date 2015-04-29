class ConfigurationProfile < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :configuration_manager
  belongs_to :parent, :class_name => 'ConfigurationProfile'
  has_and_belongs_to_many :configuration_locations, :join_table => :configuration_locations_configuration_profiles
  has_and_belongs_to_many :configuration_organizations, :join_table => :configuration_organizations_configuration_profiles

  has_many :configured_systems
  belongs_to :customization_script_ptable
  belongs_to :customization_script_medium
  belongs_to :operating_system_flavor

  alias_method :manager, :configuration_manager
end
