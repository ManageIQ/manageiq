class CloudDatabaseFlavor < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  has_many   :cloud_databases

  virtual_total :total_cloud_databases, :cloud_databases

  default_value_for :enabled, true
end
