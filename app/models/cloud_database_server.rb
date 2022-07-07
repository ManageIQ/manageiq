class CloudDatabaseServer < ApplicationRecord
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :resource_group
end
