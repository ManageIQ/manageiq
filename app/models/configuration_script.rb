class ConfigurationScript < ApplicationRecord
  serialize :variables
  serialize :survey_spec

  acts_as_miq_taggable

  belongs_to :inventory_root_group, :class_name => "EmsFolder"
  belongs_to :manager,              :class_name => "ExtManagementSystem"

  include ProviderObjectMixin
end
