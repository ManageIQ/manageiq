class ConfigurationProfile < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :configuration_manager
  has_and_belongs_to_many :configuration_locations
  has_and_belongs_to_many :configuration_organizations
end
