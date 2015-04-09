class ConfigurationTag < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  belongs_to :manager
  has_and_belongs_to_many :configured_systems
  has_and_belongs_to_many :configuration_profiles
end
