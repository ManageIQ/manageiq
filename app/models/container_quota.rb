class ContainerQuota < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project

  has_many :container_quota_scopes, :dependent => :destroy
  has_many :container_quota_items, :dependent => :destroy
end
