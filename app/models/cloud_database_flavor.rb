class CloudDatabaseFlavor < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  has_many   :cloud_databases

  virtual_column :total_cloud_databases, :type => :integer, :uses => :cloud_databases

  default_value_for :enabled, true

  def total_cloud_databases
    cloud_databases.size
  end
end
