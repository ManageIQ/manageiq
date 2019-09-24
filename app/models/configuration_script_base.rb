class ConfigurationScriptBase < ApplicationRecord
  self.table_name = "configuration_scripts"
  serialize :variables
  serialize :survey_spec

  acts_as_miq_taggable

  belongs_to :inventory_root_group, :class_name => "EmsFolder"
  belongs_to :manager,              :class_name => "ExtManagementSystem"

  belongs_to :parent,               :class_name => "ConfigurationScriptBase"
  has_many   :children,
             :class_name  => "ConfigurationScriptBase",
             :foreign_key => "parent_id",
             :dependent   => :nullify

  has_many   :authentication_configuration_script_bases,
             :dependent => :destroy
  has_many   :authentications,
             :through => :authentication_configuration_script_bases

  scope :with_manager, ->(manager_id) { where(:manager_id => manager_id) }

  include ProviderObjectMixin
end
