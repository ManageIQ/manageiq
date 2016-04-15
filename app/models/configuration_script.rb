class ConfigurationScript < ApplicationRecord
  belongs_to :inventory_root_group, :class_name => "EmsFolder"
  belongs_to :manager,              :class_name => "ExtManagementSystem", :foreign_key => :configuration_manager_id

  include ProviderObjectMixin
end
