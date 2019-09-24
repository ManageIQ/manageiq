class ConfigurationTag < ApplicationRecord
  include NewWithTypeStiMixin
  acts_as_miq_taggable

  belongs_to :manager
  has_and_belongs_to_many :configured_systems
  has_and_belongs_to_many :configuration_profiles, :join_table => :configuration_profiles_configuration_tags

  validates :name, :presence => true
end
